import 'dart:io' show File;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/widgets.dart';
import '../functionality/feed/feed_bloc.dart';
import '../services/encryption_service.dart';
import '../services/sync_service.dart';

/// 媒体文件工具类
///
/// **设计原则**：本地数据是基础，WebDAV 同步是可选增强功能。
/// UI 层优先加载本地文件；本地不存在时 **按需从 WebDAV 下载** 并缓存。
class MediaUtils {
  static SyncService? syncService;

  /// 构造媒体 URL（用于加密模式下临时预览或旧兼容）
  static String? buildMediaUrl(FeedState state, String fileName) {
    final baseUrl = state.mediaBaseUrl;
    if (baseUrl == null) return null;
    return '$baseUrl/$fileName';
  }

  /// 取首张图片 URL（旧兼容）
  static String? getFirstImageUrl(FeedState state, List<String> mediaFiles) {
    if (mediaFiles.isEmpty) return null;
    return buildMediaUrl(state, mediaFiles.first);
  }

  /// 构建图片 Widget
  ///
  /// **加载策略**：
  /// 1. 本地有 → 直接用 `Image.file` 显示
  /// 2. 本地没有 → 从 WebDAV 按需下载（如果提供了 imageUrl + httpHeaders）
  /// 3. 下载失败 → 显示占位图标
  ///
  /// **为什么保留 imageUrl / httpHeaders / encryption？**
  /// iOS 端首次打开时本地可能没有媒体文件（尚未同步），
  /// 如果不传远程 URL，图片会一直显示占位符。
  static Widget buildImage({
    required String fileName,
    required double width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
    String? imageUrl,
    Map<String, String>? httpHeaders,
    EncryptionService? encryption,
  }) {
    if (syncService == null) {
      return _placeholder(width, height);
    }
    return _LoadableImage(
      fileName: fileName,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      onTap: onTap,
      imageUrl: imageUrl,
      httpHeaders: httpHeaders ?? {},
      encryption: encryption,
    );
  }

  /// 构建全宽图片 Widget（旧兼容）
  static Widget buildFullWidthImage({
    required String fileName,
    required double screenWidth,
    BoxFit fit = BoxFit.fitWidth,
    BorderRadius? borderRadius,
    String? imageUrl,
    Map<String, String>? httpHeaders,
    EncryptionService? encryption,
  }) {
    return buildImage(
      fileName: fileName,
      width: screenWidth,
      height: null,
      fit: fit,
      borderRadius: borderRadius,
      imageUrl: imageUrl,
      httpHeaders: httpHeaders,
      encryption: encryption,
    );
  }

  static Widget _placeholder(double? width, double? height) {
    return Container(
      width: width,
      height: height ?? 200,
      color: const Color(0xFFEEEEEE),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 48, color: Color(0xFFBDBDBD)),
      ),
    );
  }

  static Widget _loadingPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height ?? 200,
      color: const Color(0xFFF5F5F5),
      child: const Center(
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// 可加载本地/远程图片的 Widget
///
/// **加载策略**：
/// 1. 检查本地文件是否存在
/// 2. 本地存在 → 直接 `Image.file`
/// 3. 本地不存在但有远程 URL → 按需下载 → 缓存到本地 → 显示
/// 4. 都没有 → 显示占位符
class _LoadableImage extends StatefulWidget {
  final String fileName;
  final double width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final String? imageUrl;
  final Map<String, String> httpHeaders;
  final EncryptionService? encryption;

  const _LoadableImage({
    required this.fileName,
    required this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.onTap,
    this.imageUrl,
    this.httpHeaders = const {},
    this.encryption,
  });

  @override
  State<_LoadableImage> createState() => _LoadableImageState();
}

class _LoadableImageState extends State<_LoadableImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sync = MediaUtils.syncService;
    if (sync == null) {
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
      return;
    }

    try {
      final localPath = await sync.getLocalMediaPath(widget.fileName);
      final file = File(localPath);

      // 1. 本地有文件
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() { _bytes = bytes; _loading = false; });
        return;
      }

      // 2. 本地没有，尝试从 WebDAV 按需下载
      if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
        final dio = Dio();
        final response = await dio.get<List<int>>(
          widget.imageUrl!,
          options: Options(
            responseType: ResponseType.bytes,
            headers: widget.httpHeaders,
          ),
        );
        if (!mounted) return;
        if (response.data != null) {
          var data = Uint8List.fromList(response.data!);
          // 解密
          if (widget.encryption != null &&
              widget.encryption!.isEncryptionEnabled) {
            data = widget.encryption!.decryptBytes(data);
          }
          // 缓存到本地
          try {
            await file.writeAsBytes(data);
            sync.localMediaFiles.add(widget.fileName);
          } catch (_) {}
          if (!mounted) return;
          setState(() { _bytes = data; _loading = false; });
          return;
        }
      }

      // 3. 都没有
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return MediaUtils._loadingPlaceholder(widget.width, widget.height);
    }

    if (_error || _bytes == null) {
      return MediaUtils._placeholder(widget.width, widget.height);
    }

    // ★ iOS 兼容：使用 Image.memory（bytes）而不是 Image.file。
    //   原因：按需下载的文件写入后，iOS 的 Image.file 可能因 sandbox 延迟
    //   而无法立即读取；Image.memory 直接使用已下载的 bytes，最可靠。
    Widget image = Image.memory(
      _bytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          MediaUtils._placeholder(widget.width, widget.height),
    );

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: image,
      );
    }
    // 没有 onTap 时，用 IgnorePointer 让点击事件穿透到父级 GestureDetector
    return IgnorePointer(child: image);
  }
}

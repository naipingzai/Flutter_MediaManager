import 'dart:io' show File;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/widgets.dart';
import '../functionality/feed_bloc.dart';
import '../services/encryption_service.dart';
import '../services/sync_service.dart';

class MediaUtils {
  static SyncService? syncService;

  static String? buildMediaUrl(FeedState state, String fileName) {
    final baseUrl = state.mediaBaseUrl;
    if (baseUrl == null) return null;
    return '$baseUrl/$fileName';
  }

  static String? getFirstImageUrl(FeedState state, List<String> mediaFiles) {
    if (mediaFiles.isEmpty) return null;
    return buildMediaUrl(state, mediaFiles.first);
  }

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
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

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
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }

    try {
      final localPath = await sync.getLocalMediaPath(widget.fileName);
      final file = File(localPath);

      // 1. 本地有文件
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
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
          if (widget.encryption != null) {
            data = widget.encryption!.decryptBytes(data);
          }
          // 缓存到本地
          try {
            await file.writeAsBytes(data);
            sync.localMediaFiles.add(widget.fileName);
          } catch (_) {}
          if (!mounted) return;
          setState(() {
            _bytes = data;
            _loading = false;
          });
          return;
        }
      }

      // 3. 都没有
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
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

import 'dart:io' show File;
import 'dart:typed_data';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/widgets.dart';
import '../functionality/feed/feed_bloc.dart';
import '../services/encryption_service.dart';
import '../services/sync_service.dart';

/// 媒体文件工具类
///
/// **设计原则**：本地数据是基础，WebDAV 同步是可选增强功能。
/// UI 层 **只加载本地文件**，云端数据由 `SyncService` 拉取/同步后写入本地。
/// 旧 API（接受 `FeedState` 等）保留以兼容旧调用，但功能已弱化（仅是工具）。
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

  /// 构建图片 Widget（**只加载本地文件**）
  ///
  /// - 本地有 → 用 `ExtendedImage.memory` 显示
  /// - 本地没有 → 显示占位图标
  ///
  /// 不做"远程回退"——那是同步机制的工作，不在 UI 层处理。
  static Widget buildImage({
    required String fileName,
    required double width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    // 兼容旧签名的可选参数（已忽略，因为不读远程）
    String? imageUrl,
    Map<String, String>? httpHeaders,
    EncryptionService? encryption,
  }) {
    if (syncService == null) {
      return _placeholder(width, height);
    }
    return FutureBuilder<String>(
      future: syncService!.getLocalMediaPath(fileName),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _loadingPlaceholder(width, height);
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _placeholder(width, height);
        }
        return _LocalImage(
          filePath: snapshot.data!,
          width: width,
          height: height,
          fit: fit,
          borderRadius: borderRadius,
        );
      },
    );
  }

  /// 构建全宽图片 Widget（旧兼容）
  static Widget buildFullWidthImage({
    required String fileName,
    required double screenWidth,
    BoxFit fit = BoxFit.fitWidth,
    BorderRadius? borderRadius,
    // 兼容旧签名的可选参数
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

/// 本地图片加载 Widget
class _LocalImage extends StatefulWidget {
  final String filePath;
  final double width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const _LocalImage({
    required this.filePath,
    required this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  State<_LocalImage> createState() => _LocalImageState();
}

class _LocalImageState extends State<_LocalImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      } else {
        throw Exception('File not found');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
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

    Widget image = ExtendedImage.memory(
      _bytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadStateChanged: (state) {
        if (state.extendedImageLoadState == LoadState.failed) {
          return MediaUtils._placeholder(widget.width, widget.height);
        }
        return null;
      },
    );

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }
    return image;
  }
}

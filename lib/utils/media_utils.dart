import 'dart:io' show File;
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
  /// - 本地有 → 直接用 `Image.file` 显示（iOS 兼容性最好）
  /// - 本地没有 → 显示占位图标
  ///
  /// **重要**：不再使用 `ExtendedImage.memory(bytes)`，因为 iOS 上 bytes 模式经常
  /// 因沙箱权限/Provider 注册问题加载失败；`Image.file` 是 Flutter 官方跨平台稳定方案。
  static Widget buildImage({
    required String fileName,
    required double width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
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
          onTap: onTap,
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

/// 本地图片加载 Widget（iOS 兼容版本）
///
/// **关键修复**：
/// - 之前用 `ExtendedImage.memory(bytes)` 在 iOS 上经常因沙箱权限/Provider
///   注册问题加载失败，导致图片不显示。
/// - 现在改用 `Image.file(File(path))`，这是 Flutter 官方跨平台最稳定的
///   本地文件加载方案，iOS/Android/Desktop 都完全一致。
/// - 同时支持 `onTap` 回调，避免 GestureDetector 包裹后吃掉 tap 事件。
class _LocalImage extends StatefulWidget {
  final String filePath;
  final double width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const _LocalImage({
    required this.filePath,
    required this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.onTap,
  });

  @override
  State<_LocalImage> createState() => _LocalImageState();
}

class _LocalImageState extends State<_LocalImage> {
  bool _exists = true;

  @override
  void initState() {
    super.initState();
    _checkFile();
  }

  Future<void> _checkFile() async {
    try {
      final exists = await File(widget.filePath).exists();
      if (!mounted) return;
      if (!exists) {
        setState(() => _exists = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _exists = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_exists) {
      return MediaUtils._placeholder(widget.width, widget.height);
    }

    // ★ iOS 兼容：直接使用 Image.file，让 Flutter 内置的 ImageProvider 处理 iOS 沙箱。
    Widget image = Image.file(
      File(widget.filePath),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          MediaUtils._placeholder(widget.width, widget.height),
      frameBuilder: (context, child, frame, wasSyncLoaded) {
        if (wasSyncLoaded) return child;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: frame == null
              ? MediaUtils._loadingPlaceholder(widget.width, widget.height)
              : child,
        );
      },
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
    return image;
  }
}

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../functionality/feed/feed_bloc.dart';
import '../services/encryption_service.dart';
import '../services/cache_service.dart';

/// 媒体文件工具类
class MediaUtils {
  /// 全局缓存服务引用（由 main.dart 设置）
  static CacheService? cacheService;
  /// 构建媒体文件完整 URL
  /// Web 平台会自动在 URL 中附加 auth 查询参数（因为 <img> 标签无法发送自定义头）
  static String? buildMediaUrl(FeedState state, String fileName) {
    final baseUrl = state.mediaBaseUrl;
    if (baseUrl == null) return null;
    final url = '$baseUrl/$fileName';
    if (kIsWeb && state.imageHeaders.isNotEmpty) {
      final auth = state.imageHeaders['Authorization'] ?? '';
      if (auth.isNotEmpty) {
        final encoded = Uri.encodeComponent(auth);
        return '$url?auth=$encoded';
      }
    }
    return url;
  }

  static Widget _buildPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height ?? 200,
      color: Colors.grey[100],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  /// 获取帖子的第一张图片 URL
  static String? getFirstImageUrl(FeedState state, List<String> mediaFiles) {
    if (mediaFiles.isEmpty) return null;
    return buildMediaUrl(state, mediaFiles.first);
  }

  /// 构建图片 Widget（支持本地预览和远程加载）
  static Widget buildImage({
    required String? imageUrl,
    required double width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Map<String, String>? httpHeaders,
    EncryptionService? encryption,
  }) {
    if (imageUrl == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: borderRadius,
        ),
        child: const Center(
          child: Icon(Icons.image_outlined, size: 32, color: Colors.grey),
        ),
      );
    }

    // 缓存优先：如果缓存中存在，直接从本地加载
    if (cacheService != null && cacheService!.enabled) {
      final fileName = imageUrl.split('/').last;
      if (cacheService!.isCached(fileName)) {
        return FutureBuilder<String?>(
          future: cacheService!.getLocalPath(fileName),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final file = File(snapshot.data!);
              if (file.existsSync()) {
                Widget image = Image.file(
                  file,
                  width: width,
                  height: height,
                  fit: fit,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(width, height),
                );
                if (borderRadius != null) {
                  return ClipRRect(borderRadius: borderRadius, child: image);
                }
                return image;
              }
            }
            return _buildPlaceholder(width, height);
          },
        );
      }
    }

    // 加密模式：先下载再解密
    if (encryption != null && encryption.isEncryptionEnabled) {
      return _EncryptedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        borderRadius: borderRadius,
        httpHeaders: httpHeaders ?? const {},
        encryption: encryption,
      );
    }

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      httpHeaders: httpHeaders ?? const {},
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: Colors.grey[100],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Center(
          child:
              Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey),
        ),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: image,
      );
    }

    return image;
  }

  /// 构建全宽图片 Widget（按比例显示）
  static Widget buildFullWidthImage({
    required String? imageUrl,
    required double screenWidth,
    BoxFit fit = BoxFit.fitWidth,
    Map<String, String>? httpHeaders,
    EncryptionService? encryption,
  }) {
    if (imageUrl == null) {
      return Container(
        width: screenWidth,
        height: 200,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_outlined, size: 48, color: Colors.grey),
        ),
      );
    }

    // 缓存优先
    if (cacheService != null && cacheService!.enabled) {
      final fileName = imageUrl.split('/').last;
      if (cacheService!.isCached(fileName)) {
        return FutureBuilder<String?>(
          future: cacheService!.getLocalPath(fileName),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final file = File(snapshot.data!);
              if (file.existsSync()) {
                return Image.file(
                  file,
                  width: screenWidth,
                  fit: fit,
                  errorBuilder: (_, __, ___) => Container(
                    width: screenWidth,
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 48, color: Colors.grey),
                    ),
                  ),
                );
              }
            }
            return Container(
              width: screenWidth,
              height: 200,
              color: Colors.grey[100],
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        );
      }
    }

    // 加密模式
    if (encryption != null && encryption.isEncryptionEnabled) {
      return _EncryptedNetworkImage(
        imageUrl: imageUrl,
        width: screenWidth,
        height: 200,
        fit: fit,
        httpHeaders: httpHeaders ?? const {},
        encryption: encryption,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: screenWidth,
      fit: fit,
      httpHeaders: httpHeaders ?? const {},
      placeholder: (context, url) => Container(
        width: screenWidth,
        height: 200,
        color: Colors.grey[100],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: screenWidth,
        height: 200,
        color: Colors.grey[200],
        child: const Center(
          child:
              Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
        ),
      ),
    );
  }
}

/// 加密网络图片组件 - 下载后解密显示
class _EncryptedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Map<String, String> httpHeaders;
  final EncryptionService encryption;

  const _EncryptedNetworkImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    required this.httpHeaders,
    required this.encryption,
  });

  @override
  State<_EncryptedNetworkImage> createState() => _EncryptedNetworkImageState();
}

class _EncryptedNetworkImageState extends State<_EncryptedNetworkImage> {
  Uint8List? _decryptedData;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_EncryptedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        widget.imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: widget.httpHeaders,
        ),
      );
      if (!mounted) return;
      if (response.data != null) {
        final decrypted =
            widget.encryption.decryptBytes(Uint8List.fromList(response.data!));
        setState(() {
          _decryptedData = decrypted;
          _loading = false;
        });
      } else {
        setState(() {
          _error = true;
          _loading = false;
        });
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
      return Container(
        width: widget.width,
        height: widget.height ?? 200,
        color: Colors.grey[100],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error || _decryptedData == null) {
      return Container(
        width: widget.width,
        height: widget.height ?? 200,
        color: Colors.grey[200],
        child: const Center(
          child:
              Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey),
        ),
      );
    }

    Widget image = Image.memory(
      _decryptedData!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => Container(
        width: widget.width,
        height: widget.height ?? 200,
        color: Colors.grey[200],
        child: const Center(
          child:
              Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey),
        ),
      ),
    );

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }
    return image;
  }
}

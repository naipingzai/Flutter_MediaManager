import 'dart:io';
import 'package:extended_image/extended_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../functionality/feed/feed_bloc.dart';
import '../services/encryption_service.dart';
import '../services/cache_service.dart';

/// 媒体文件工具类
class MediaUtils {
  static CacheService? cacheService;

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
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  static String? getFirstImageUrl(FeedState state, List<String> mediaFiles) {
    if (mediaFiles.isEmpty) return null;
    return buildMediaUrl(state, mediaFiles.first);
  }

  /// 构建图片 Widget
  /// 优先级：本地文件 → 远程加密下载缓存 → 远程直接加载
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
        width: width, height: height,
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: borderRadius),
        child: const Center(child: Icon(Icons.image_outlined, size: 32, color: Colors.grey)),
      );
    }

    final fileName = imageUrl.split('/').last.split('?').first;

    // 本地文件优先（明文，不加密）
    if (cacheService != null) {
      final localPath = cacheService!.getLocalMediaPath(fileName);
      return FutureBuilder<String>(
        future: localPath,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final file = File(snapshot.data!);
            if (file.existsSync()) {
              Widget image = ExtendedImage.file(
                file,
                width: width, height: height, fit: fit,
                loadStateChanged: (state) {
                  if (state.extendedImageLoadState == LoadState.failed) {
                    return _buildPlaceholder(width, height);
                  }
                  return null;
                },
              );
              if (borderRadius != null) return ClipRRect(borderRadius: borderRadius, child: image);
              return image;
            }
          }
          return _buildNetworkImage(
            imageUrl: imageUrl, fileName: fileName,
            width: width, height: height, fit: fit,
            borderRadius: borderRadius, httpHeaders: httpHeaders, encryption: encryption,
          );
        },
      );
    }

    return _buildNetworkImage(
      imageUrl: imageUrl, fileName: fileName,
      width: width, height: height, fit: fit,
      borderRadius: borderRadius, httpHeaders: httpHeaders, encryption: encryption,
    );
  }

  /// 构建全宽图片 Widget
  static Widget buildFullWidthImage({
    required String? imageUrl,
    required double screenWidth,
    BoxFit fit = BoxFit.fitWidth,
    Map<String, String>? httpHeaders,
    EncryptionService? encryption,
  }) {
    if (imageUrl == null) {
      return Container(
        width: screenWidth, height: 200, color: Colors.grey[200],
        child: const Center(child: Icon(Icons.image_outlined, size: 48, color: Colors.grey)),
      );
    }

    final fileName = imageUrl.split('/').last.split('?').first;

    if (cacheService != null) {
      final localPath = cacheService!.getLocalMediaPath(fileName);
      return FutureBuilder<String>(
        future: localPath,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final file = File(snapshot.data!);
            if (file.existsSync()) {
              return ExtendedImage.file(
                file,
                width: screenWidth, fit: fit,
                loadStateChanged: (state) {
                  if (state.extendedImageLoadState == LoadState.failed) {
                    return Container(
                      width: screenWidth, height: 200, color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey)),
                    );
                  }
                  return null;
                },
              );
            }
          }
          return _buildNetworkImage(
            imageUrl: imageUrl, fileName: fileName,
            width: screenWidth, height: 200, fit: fit,
            httpHeaders: httpHeaders, encryption: encryption,
          );
        },
      );
    }

    return _buildNetworkImage(
      imageUrl: imageUrl, fileName: fileName,
      width: screenWidth, height: 200, fit: fit,
      httpHeaders: httpHeaders, encryption: encryption,
    );
  }

  static Widget _buildNetworkImage({
    required String imageUrl,
    required String fileName,
    required double width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Map<String, String>? httpHeaders,
    EncryptionService? encryption,
  }) {
    // 加密模式：下载解密后缓存到本地
    if (encryption != null && encryption.isEncryptionEnabled) {
      return _EncryptedCachedImage(
        imageUrl: imageUrl, fileName: fileName,
        width: width, height: height, fit: fit,
        borderRadius: borderRadius,
        httpHeaders: httpHeaders ?? const {},
        encryption: encryption,
      );
    }

    // 非加密：extended_image 网络加载
    Widget image = ExtendedImage.network(
      imageUrl,
      width: width, height: height, fit: fit,
      headers: httpHeaders,
      loadStateChanged: (state) {
        if (state.extendedImageLoadState == LoadState.loading) {
          return _buildPlaceholder(width, height);
        }
        if (state.extendedImageLoadState == LoadState.failed) {
          return Container(
            width: width, height: height, color: Colors.grey[200],
            child: const Center(child: Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey)),
          );
        }
        return null;
      },
    );

    if (borderRadius != null) return ClipRRect(borderRadius: borderRadius, child: image);
    return image;
  }
}

/// 加密网络图片 —— 下载解密后缓存到本地
class _EncryptedCachedImage extends StatefulWidget {
  final String imageUrl;
  final String fileName;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Map<String, String> httpHeaders;
  final EncryptionService encryption;

  const _EncryptedCachedImage({
    required this.imageUrl, required this.fileName,
    this.width, this.height, this.fit = BoxFit.cover,
    this.borderRadius,
    required this.httpHeaders, required this.encryption,
  });

  @override
  State<_EncryptedCachedImage> createState() => _EncryptedCachedImageState();
}

class _EncryptedCachedImageState extends State<_EncryptedCachedImage> {
  Uint8List? _decryptedData;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_EncryptedCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _loadImage();
  }

  Future<void> _loadImage() async {
    setState(() { _loading = true; _error = false; });
    try {
      // 先检查本地缓存
      if (MediaUtils.cacheService != null) {
        final localPath = await MediaUtils.cacheService!.getLocalMediaPath(widget.fileName);
        final localFile = File(localPath);
        if (await localFile.exists()) {
          final bytes = await localFile.readAsBytes();
          if (!mounted) return;
          setState(() { _decryptedData = bytes; _loading = false; });
          return;
        }
      }

      // 下载并解密
      final dio = Dio();
      final response = await dio.get<List<int>>(
        widget.imageUrl,
        options: Options(responseType: ResponseType.bytes, headers: widget.httpHeaders),
      );
      if (!mounted) return;
      if (response.data != null) {
        final decrypted = widget.encryption.decryptBytes(Uint8List.fromList(response.data!));
        // 缓存到本地（明文）
        if (MediaUtils.cacheService != null) {
          final localPath = await MediaUtils.cacheService!.getLocalMediaPath(widget.fileName);
          await File(localPath).writeAsBytes(decrypted);
          MediaUtils.cacheService!.cachedFiles.add(widget.fileName);
        }
        setState(() { _decryptedData = decrypted; _loading = false; });
      } else {
        setState(() { _error = true; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Container(
      width: widget.width, height: widget.height ?? 200, color: Colors.grey[100],
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
    if (_error || _decryptedData == null) return Container(
      width: widget.width, height: widget.height ?? 200, color: Colors.grey[200],
      child: const Center(child: Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey)),
    );

    Widget image = ExtendedImage.memory(
      _decryptedData!,
      width: widget.width, height: widget.height, fit: widget.fit,
      loadStateChanged: (state) {
        if (state.extendedImageLoadState == LoadState.failed) {
          return Container(
            width: widget.width, height: widget.height ?? 200, color: Colors.grey[200],
            child: const Center(child: Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey)),
          );
        }
        return null;
      },
    );

    if (widget.borderRadius != null) return ClipRRect(borderRadius: widget.borderRadius!, child: image);
    return image;
  }
}

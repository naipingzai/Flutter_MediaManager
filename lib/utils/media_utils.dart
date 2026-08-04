import 'dart:io' show File;
import 'dart:typed_data';
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
  /// [fileName] 是必填的（用于本地文件查找），[imageUrl] 可选（用于云端加载）
  static Widget buildImage({
    required String fileName,
    String? imageUrl,
    required double width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Map<String, String>? httpHeaders,
    EncryptionService? encryption,
  }) {
    // 本地文件优先（无论是否有 WebDAV）
    if (cacheService != null) {
      final localPathFuture = cacheService!.getLocalMediaPath(fileName);
      return FutureBuilder<String>(
        future: localPathFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return _LoadLocalImage(
              filePath: snapshot.data!,
              fileName: fileName,
              imageUrl: imageUrl,
              width: width,
              height: height,
              fit: fit,
              borderRadius: borderRadius,
              httpHeaders: httpHeaders,
              encryption: encryption,
            );
          }
          // 本地文件不存在，回退到网络（如果有URL）
          if (imageUrl != null) {
            return _buildNetworkImage(
              imageUrl: imageUrl, fileName: fileName,
              width: width, height: height, fit: fit,
              borderRadius: borderRadius, httpHeaders: httpHeaders, encryption: encryption,
            );
          }
          // 没有本地也没有URL，显示占位符
          return Container(
            width: width, height: height,
            color: Colors.grey[200],
            child: const Center(child: Icon(Icons.image_outlined, size: 32, color: Colors.grey)),
          );
        },
      );
    }

    // 没有 cacheService 时只能走网络
    if (imageUrl != null) {
      return _buildNetworkImage(
        imageUrl: imageUrl, fileName: fileName,
        width: width, height: height, fit: fit,
        borderRadius: borderRadius, httpHeaders: httpHeaders, encryption: encryption,
      );
    }
    return Container(
      width: width, height: height,
      color: Colors.grey[200],
      child: const Center(child: Icon(Icons.image_outlined, size: 32, color: Colors.grey)),
    );
  }

  /// 构建全宽图片 Widget（详情页用）
  static Widget buildFullWidthImage({
    required String fileName,
    String? imageUrl,
    required double screenWidth,
    BoxFit fit = BoxFit.fitWidth,
    Map<String, String>? httpHeaders,
    EncryptionService? encryption,
  }) {
    if (cacheService != null) {
      final localPathFuture = cacheService!.getLocalMediaPath(fileName);
      return FutureBuilder<String>(
        future: localPathFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return _LoadLocalImage(
              filePath: snapshot.data!,
              fileName: fileName,
              imageUrl: imageUrl,
              width: screenWidth,
              height: 200,
              fit: fit,
              httpHeaders: httpHeaders,
              encryption: encryption,
            );
          }
          if (imageUrl != null) {
            return _buildNetworkImage(
              imageUrl: imageUrl, fileName: fileName,
              width: screenWidth, height: 200, fit: fit,
              httpHeaders: httpHeaders, encryption: encryption,
            );
          }
          return Container(
            width: screenWidth, height: 200, color: Colors.grey[200],
            child: const Center(child: Icon(Icons.image_outlined, size: 48, color: Colors.grey)),
          );
        },
      );
    }

    if (imageUrl != null) {
      return _buildNetworkImage(
        imageUrl: imageUrl, fileName: fileName,
        width: screenWidth, height: 200, fit: fit,
        httpHeaders: httpHeaders, encryption: encryption,
      );
    }
    return Container(
      width: screenWidth, height: 200, color: Colors.grey[200],
      child: const Center(child: Icon(Icons.image_outlined, size: 48, color: Colors.grey)),
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

/// 加载本地缓存图片的 Widget
class _LoadLocalImage extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Map<String, String>? httpHeaders;
  final EncryptionService? encryption;

  const _LoadLocalImage({
    required this.filePath,
    required this.fileName,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.httpHeaders,
    this.encryption,
  });

  @override
  State<_LoadLocalImage> createState() => _LoadLocalImageState();
}

class _LoadLocalImageState extends State<_LoadLocalImage> {
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
      return Container(
        width: widget.width,
        height: widget.height ?? 200,
        color: Colors.grey[100],
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error || _bytes == null) {
      // 回退到网络加载
      if (widget.imageUrl != null) {
        return MediaUtils._buildNetworkImage(
          imageUrl: widget.imageUrl!,
          fileName: widget.fileName,
          width: widget.width ?? 200,
          height: widget.height,
          fit: widget.fit,
          borderRadius: widget.borderRadius,
          httpHeaders: widget.httpHeaders,
          encryption: widget.encryption,
        );
      }
      return Container(
        width: widget.width,
        height: widget.height ?? 200,
        color: Colors.grey[200],
        child: const Center(child: Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey)),
      );
    }

    Widget image = ExtendedImage.memory(
      _bytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadStateChanged: (state) {
        if (state.extendedImageLoadState == LoadState.failed) {
          return Container(
            width: widget.width,
            height: widget.height ?? 200,
            color: Colors.grey[200],
            child: const Center(child: Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey)),
          );
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

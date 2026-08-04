import 'dart:io' show File;
import 'dart:typed_data';
import 'package:extended_image/extended_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../functionality/feed/feed_bloc.dart';
import '../services/encryption_service.dart';
import '../services/sync_service.dart';

/// 媒体文件工具类
class MediaUtils {
  static SyncService? syncService;

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
    if (syncService != null) {
      final localPathFuture = syncService!.getLocalMediaPath(fileName);
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
          if (imageUrl != null) {
            return _buildNetworkImage(
              imageUrl: imageUrl, fileName: fileName,
              width: width, height: height, fit: fit,
              borderRadius: borderRadius, httpHeaders: httpHeaders, encryption: encryption,
            );
          }
          return _placeholder(width, height, Icons.image_outlined, size: 32);
        },
      );
    }

    if (imageUrl != null) {
      return _buildNetworkImage(
        imageUrl: imageUrl, fileName: fileName,
        width: width, height: height, fit: fit,
        borderRadius: borderRadius, httpHeaders: httpHeaders, encryption: encryption,
      );
    }
    return _placeholder(width, height, Icons.image_outlined, size: 32);
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
    if (syncService != null) {
      final localPathFuture = syncService!.getLocalMediaPath(fileName);
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
          return _placeholder(screenWidth, 200, Icons.image_outlined, size: 48);
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
    return _placeholder(screenWidth, 200, Icons.image_outlined, size: 48);
  }

  static Widget _placeholder(double? width, double? height, IconData icon,
      {double size = 32}) {
    return Container(
      width: width,
      height: height ?? 200,
      color: Colors.grey[200],
      child: Center(child: Icon(icon, size: size, color: Colors.grey)),
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
    if (encryption != null && encryption.isEncryptionEnabled) {
      return _EncryptedCachedImage(
        imageUrl: imageUrl, fileName: fileName,
        width: width, height: height, fit: fit,
        borderRadius: borderRadius,
        httpHeaders: httpHeaders ?? const {},
        encryption: encryption,
      );
    }

    Widget image = ExtendedImage.network(
      imageUrl,
      width: width, height: height, fit: fit,
      headers: httpHeaders,
      loadStateChanged: (state) {
        if (state.extendedImageLoadState == LoadState.loading) {
          return Container(
            width: width,
            height: height ?? 200,
            color: Colors.grey[100],
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (state.extendedImageLoadState == LoadState.failed) {
          return Container(
            width: width, height: height, color: Colors.grey[200],
            child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    size: 32, color: Colors.grey)),
          );
        }
        return null;
      },
    );

    if (borderRadius != null) return ClipRRect(borderRadius: borderRadius, child: image);
    return image;
  }
}

/// 加载本地数据图片的 Widget
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
        child: const Center(
            child: Icon(Icons.broken_image_outlined,
                size: 32, color: Colors.grey)),
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
            child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    size: 32, color: Colors.grey)),
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
      if (MediaUtils.syncService != null) {
        final localPath =
            await MediaUtils.syncService!.getLocalMediaPath(widget.fileName);
        final localFile = File(localPath);
        if (await localFile.exists()) {
          final bytes = await localFile.readAsBytes();
          if (!mounted) return;
          setState(() { _decryptedData = bytes; _loading = false; });
          return;
        }
      }

      final dio = Dio();
      final response = await dio.get<List<int>>(
        widget.imageUrl,
        options: Options(
            responseType: ResponseType.bytes, headers: widget.httpHeaders),
      );
      if (!mounted) return;
      if (response.data != null) {
        final decrypted = widget.encryption
            .decryptBytes(Uint8List.fromList(response.data!));
        if (MediaUtils.syncService != null) {
          final localPath =
              await MediaUtils.syncService!.getLocalMediaPath(widget.fileName);
          await File(localPath).writeAsBytes(decrypted);
          MediaUtils.syncService!.localMediaFiles.add(widget.fileName);
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
    if (_loading) {
      return Container(
        width: widget.width, height: widget.height ?? 200, color: Colors.grey[100],
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error || _decryptedData == null) {
      return Container(
        width: widget.width, height: widget.height ?? 200, color: Colors.grey[200],
        child: const Center(
            child: Icon(Icons.broken_image_outlined,
                size: 32, color: Colors.grey)),
      );
    }

    Widget image = ExtendedImage.memory(
      _decryptedData!,
      width: widget.width, height: widget.height, fit: widget.fit,
      loadStateChanged: (state) {
        if (state.extendedImageLoadState == LoadState.failed) {
          return Container(
            width: widget.width,
            height: widget.height ?? 200,
            color: Colors.grey[200],
            child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    size: 32, color: Colors.grey)),
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

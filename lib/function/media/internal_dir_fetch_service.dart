import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_media_view/ui/image_providers/region_provider.dart';
import 'package:flutter_media_view/ui/image_providers/thumbnail_provider.dart';
import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/model/mime_types.dart';
import 'package:flutter_media_view/function/media/fetch_service.dart';
import 'package:fmv_report/flutter_media_view_report.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// 内部目录取图服务：从 `<docs>/library` 的文件路径直接解码。
///
/// 替代 Fmv 原生 `PlatformMediaFetchService`（走 Android MediaStore content URI）。
/// 图片用 Flutter 内置解码，视频用 [video_thumbnail] 生成封面。
/// 跨平台（Android/iOS/Linux 通用）。
class InternalDirMediaFetchService implements MediaFetchService {
  /// `file://` URI -> 本地绝对路径
  static String? _filePathFromUri(String uri) {
    if (uri.startsWith('file://')) return uri.substring('file://'.length);
    if (uri.startsWith('/')) return uri;
    return null;
  }

  Future<Uint8List> _readFile(String uri) async {
    final path = _filePathFromUri(uri);
    if (path == null) throw UnreportedStateError('not a file uri: $uri');
    final file = File(path);
    if (!await file.exists()) throw UnreportedStateError('missing file: $path');
    return file.readAsBytes();
  }

  Future<ui.Codec> _codecFromBytes(Uint8List bytes, ImageDecoderCallback? decode) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    if (decode != null) return decode(buffer);
    return ui.instantiateImageCodecFromBuffer(buffer);
  }

  @override
  Future<FmvEntry?> getEntry(String uri, String? mimeType, {bool allowUnsized = false}) async {
    final path = _filePathFromUri(uri);
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final stat = await file.stat();
    return FmvEntry(
      id: null,
      uri: uri,
      path: path,
      pageId: null,
      contentId: stableHash(path),
      sourceMimeType: mimeType ?? 'application/octet-stream',
      width: 0,
      height: 0,
      sourceRotationDegrees: 0,
      sizeBytes: stat.size,
      sourceTitle: path.split('/').last,
      dateAddedSecs: (stat.modified.millisecondsSinceEpoch / 1000).round(),
      dateModifiedMillis: stat.modified.millisecondsSinceEpoch,
      sourceDateTakenMillis: stat.modified.millisecondsSinceEpoch,
      durationMillis: null,
      trashed: false,
      origin: 0,
    );
  }

  @override
  Future<Uint8List> getOriginalBytes(FmvEntry entry) async {
    final bytes = await _readFile(entry.uri);
    if (bytes.isEmpty) throw UnreportedStateError('empty file for ${entry.uri}');
    return bytes;
  }

  @override
  Future<ui.Codec> getFullImage({
    required bool decoded,
    required ImageRequest request,
    required ImageDecoderCallback decode,
  }) async {
    final bytes = await _readFile(request.uri);
    return _codecFromBytes(bytes, decode);
  }

  @override
  Future<ui.Codec> getRegion({
    required bool decoded,
    required RegionProviderKey request,
    required ImageDecoderCallback decode,
    Object? taskKey,
    int? priority,
  }) async {
    // 简化：区域解码退回整图解码（对内部目录已足够）
    final bytes = await _readFile(request.uri);
    return _codecFromBytes(bytes, decode);
  }

  @override
  Future<ui.Codec> getThumbnail({
    required bool decoded,
    required ThumbnailProviderKey request,
    ImageDecoderCallback? decode,
    Object? taskKey,
    int? priority,
  }) async {
    final path = _filePathFromUri(request.uri);
    if (path == null) throw UnreportedStateError('not a file uri: ${request.uri}');

    if (request.mimeType.startsWith('video/') || request.mimeType == MimeTypes.avif) {
      final bytes = await _videoThumb(path);
      if (bytes == null) {
        throw UnreportedStateError('no video thumbnail for $path');
      }
      return _codecFromBytes(bytes, decode);
    }

    final bytes = await _readFile(request.uri);
    return _codecFromBytes(bytes, decode);
  }

  Future<Uint8List?> _videoThumb(String path) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        quality: 60,
        maxWidth: 480,
        timeMs: 1000,
      ).timeout(const Duration(seconds: 8), onTimeout: () => null);
    } catch (error) {
      debugPrint('$runtimeType video thumbnail failed: $error');
    }
    return null;
  }

  @override
  Future<void> clearDecoders() async {}

  @override
  Future<void> clearImageDiskCache() async {}

  @override
  Future<void> clearImageMemoryCache() async {}

  @override
  bool cancelRegion(Object taskKey) => true;

  @override
  bool cancelThumbnail(Object taskKey) => true;

  @override
  Future<T>? resumeLoading<T>(Object taskKey) => null;
}

/// 稳定哈希（跨运行/平台一致），用于内部文件 contentId 去重。
int stableHash(String input) {
  var hash = 0x811C9DC5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

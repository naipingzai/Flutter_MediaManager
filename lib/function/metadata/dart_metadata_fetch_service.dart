import 'dart:convert';

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_props.dart';
import 'package:flutter_media_view/function/media/media_geotiff.dart';
import 'package:flutter_media_view/function/media/panorama.dart';
import 'package:flutter_media_view/function/metadata/catalog.dart';
import 'package:flutter_media_view/function/metadata/overlay.dart';
import 'package:flutter_media_view/function/media/multipage.dart';
import 'package:flutter_media_view/function/model/mime_types.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/function/metadata/metadata_fetch_service.dart';
import 'package:flutter_media_view/function/services/function_services_metadata_xmp.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 纯 Dart 元数据服务：用 `image`（EXIF）+ `xml`（XMP）解析图片元数据。
///
/// 跨平台（Android/iOS/Linux/Windows 通用），替代 Fmv 原生 `PlatformMetadataFetchService`
/// （该实现依赖 Android/iOS 平台通道）。视频元数据仍由 `MpvVideoMetadataFetcher` 处理，
/// 这里只负责图片。
class DartMetadataFetchService implements MetadataFetchService {
  // ── 读取文件 ──

  Future<Uint8List?> _readBytes(FmvEntry entry) async {
    try {
      return await mediaFetchService.getOriginalBytes(entry);
    } catch (error, stack) {
      debugPrint('$runtimeType failed to read bytes for $entry: $error\n$stack');
    }
    return null;
  }

  // ── EXIF ──

  img.ExifData? _getExif(FmvEntry entry, Uint8List bytes) {
    if (entry.mimeType == MimeTypes.jpeg || entry.mimeType == MimeTypes.tiff) {
      try {
        return img.decodeJpgExif(bytes);
      } catch (error) {
        debugPrint('$runtimeType failed to parse EXIF for $entry: $error');
      }
    }
    return null;
  }

  String? _exifString(img.IfdDirectory? ifd, int tag) => ifd?[tag]?.toString();

  int? _exifInt(img.IfdDirectory? ifd, int tag) => ifd?[tag]?.toInt();

  double? _exifDouble(img.IfdDirectory? ifd, int tag) => ifd?[tag]?.toDouble();

  // 解析 GPS 坐标：EXIF 用三组 rational 表示度/分/秒
  double? _gpsCoordinate(img.IfdDirectory? gpsIfd, int refTag, int coordTag) {
    final ref = _exifString(gpsIfd, refTag);
    final coords = _exifRationals(gpsIfd, coordTag);
    if (ref == null || coords == null) return null;

    final degree = coords.isNotEmpty ? coords[0] : 0.0;
    final minute = coords.length > 1 ? coords[1] : 0.0;
    final second = coords.length > 2 ? coords[2] : 0.0;
    var value = degree + minute / 60 + second / 3600;
    if (ref == 'S' || ref == 'W') value = -value;
    return value;
  }

  List<double>? _exifRationals(img.IfdDirectory? ifd, int tag) {
    final value = ifd?[tag];
    if (value == null) return null;
    try {
      return [for (var i = 0; i < value.length; i++) value.toDouble(i)];
    } catch (_) {
      return null;
    }
  }

  // ── 主入口 ──

  @override
  Future<CatalogMetadata?> getCatalogMetadata(FmvEntry entry, {bool background = false}) async {
    if (entry.isSvg) return CatalogMetadata(id: entry.id);

    final bytes = await _readBytes(entry);
    final exif = bytes == null ? null : _getExif(entry, bytes);

    var catalog = CatalogMetadata(id: entry.id, mimeType: entry.mimeType);

    if (exif != null) {
      final exifIfd = exif.exifIfd;
      final gpsIfd = exif.gpsIfd;
      final imageIfd = exif.imageIfd;

      final dateString = _exifString(exifIfd, 0x9003) ?? _exifString(exifIfd, 0x0132);
      final date = dateString == null ? null : DateTime.tryParse(dateString.replaceFirst(' ', 'T'));
      if (date != null) {
        catalog = catalog.copyWith(id: catalog.id, dateMillis: date.millisecondsSinceEpoch);
      }

      final orientation = _exifInt(imageIfd, 0x0112);
      int? rotationDegrees;
      if (orientation != null) {
        // EXIF orientation -> rotation degrees
        switch (orientation) {
          case 3:
            rotationDegrees = 180;
          case 6:
            rotationDegrees = 90;
          case 8:
            rotationDegrees = 270;
          case 5:
            rotationDegrees = 270;
          case 7:
            rotationDegrees = 90;
        }
      }
      if (rotationDegrees != null) {
        catalog = catalog.copyWith(rotationDegrees: rotationDegrees);
      }

      final latitude = _gpsCoordinate(gpsIfd, 0x0001, 0x0002);
      final longitude = _gpsCoordinate(gpsIfd, 0x0003, 0x0004);
      if (latitude != null && longitude != null) {
        catalog = catalog.copyWith(latitude: latitude, longitude: longitude);
      }
    }

    // XMP：标题、标签
    if (bytes != null) {
      final xmp = _parseXmp(bytes);
      if (xmp != null && (xmp.title != null || (xmp.subjects?.isNotEmpty ?? false))) {
        catalog = CatalogMetadata(
          id: catalog.id,
          mimeType: catalog.mimeType,
          dateMillis: catalog.dateMillis,
          isAnimated: catalog.isAnimated,
          isFlipped: catalog.isFlipped,
          isGeotiff: catalog.isGeotiff,
          is360: catalog.is360,
          isMultiPage: catalog.isMultiPage,
          isMotionPhoto: catalog.isMotionPhoto,
          isHdr: catalog.isHdr,
          isSlowMotion: catalog.isSlowMotion,
          rotationDegrees: catalog.rotationDegrees,
          xmpSubjects: xmp.subjects?.join(';'),
          xmpTitle: xmp.title,
          latitude: catalog.latitude,
          longitude: catalog.longitude,
          rating: catalog.rating,
        );
      }
    }

    return catalog;
  }

  @override
  Future<OverlayMetadata> getOverlayMetadata(FmvEntry entry, Set<MetadataSyntheticField> fields) async {
    if (fields.isEmpty || entry.isSvg) return const OverlayMetadata();

    final bytes = await _readBytes(entry);
    final exif = bytes == null ? null : _getExif(entry, bytes);
    if (exif == null) return const OverlayMetadata();

    final exifIfd = exif.exifIfd;
    return OverlayMetadata(
      aperture: fields.contains(MetadataSyntheticField.aperture) ? _exifDouble(exifIfd, 0x829D) : null,
      description: fields.contains(MetadataSyntheticField.description) ? _exifString(imageIfdOf(exif), 0x010E) : null,
      exposureTime: fields.contains(MetadataSyntheticField.exposureTime) ? _exifString(exifIfd, 0x829A) : null,
      focalLength: fields.contains(MetadataSyntheticField.focalLength) ? _exifDouble(exifIfd, 0x920A) : null,
      iso: fields.contains(MetadataSyntheticField.iso) ? _exifInt(exifIfd, 0x8827) : null,
    );
  }

  img.IfdDirectory? imageIfdOf(img.ExifData exif) => exif.imageIfd;

  @override
  Future<Map> getAllMetadata(FmvEntry entry) async {
    if (entry.isSvg) return {};

    final bytes = await _readBytes(entry);
    if (bytes == null) return {};

    final exif = _getExif(entry, bytes);
    final result = <String, Map<String, String>>{};
    if (exif != null) {
      final dir = <String, String>{};
      for (final name in exif.directories.keys) {
        final directory = exif.directories[name]!;
        for (final tag in directory.keys) {
          final value = directory[tag];
          if (value != null) {
            dir[exif.getTagName(tag)] = value.toString();
          }
        }
      }
      if (dir.isNotEmpty) result['Exif'] = dir;
    }
    return result;
  }

  @override
  Future<GeoTiffInfo?> getGeoTiffInfo(FmvEntry entry) async => null;

  @override
  Future<MultiPageInfo?> getMultiPageInfo(FmvEntry entry) async => null;

  @override
  Future<PanoramaInfo?> getPanoramaInfo(FmvEntry entry) async => null;

  @override
  Future<List<Map<String, dynamic>>?> getIptc(FmvEntry entry) async {
    final bytes = await _readBytes(entry);
    return bytes == null ? null : _parseIptc(bytes);
  }

  @override
  Future<FmvXmp?> getXmp(FmvEntry entry) async {
    final bytes = await _readBytes(entry);
    if (bytes == null) return null;
    final xmpString = _extractXmpPacket(bytes);
    return xmpString == null ? null : FmvXmp(xmpString: xmpString);
  }

  @override
  Future<bool> hasContentResolverProp(String prop) async => false;

  @override
  Future<String?> getContentResolverProp(FmvEntry entry, String prop) async => null;

  @override
  Future<DateTime?> getDate(FmvEntry entry, MetadataField field) async {
    final bytes = await _readBytes(entry);
    final exif = bytes == null ? null : _getExif(entry, bytes);
    if (exif == null) return null;
    final exifIfd = exif.exifIfd;
    final dateString = switch (field) {
      MetadataField.exifDate => _exifString(exifIfd, 0x0132),
      MetadataField.exifDateOriginal => _exifString(exifIfd, 0x9003),
      MetadataField.exifDateDigitized => _exifString(exifIfd, 0x9004),
      _ => null,
    };
    if (dateString == null) return null;
    final date = DateTime.tryParse(dateString.replaceFirst(' ', 'T'));
    return date;
  }

  @override
  Future<Map<String, Object?>> getFields(FmvEntry entry, Set<MetadataField> fields) async {
    if (fields.isEmpty) return {};

    final bytes = await _readBytes(entry);
    final exif = bytes == null ? null : _getExif(entry, bytes);
    final result = <String, Object?>{};
    if (exif != null) {
      final exifIfd = exif.exifIfd;
      final imageIfd = exif.imageIfd;
      if (fields.contains(MetadataField.exifMake)) result[MetadataField.exifMake.name] = _exifString(imageIfd, 0x010F);
      if (fields.contains(MetadataField.exifModel)) result[MetadataField.exifModel.name] = _exifString(imageIfd, 0x0110);
      if (fields.contains(MetadataField.exifImageDescription)) result[MetadataField.exifImageDescription.name] = _exifString(imageIfd, 0x010E);
      if (fields.contains(MetadataField.exifUserComment)) result[MetadataField.exifUserComment.name] = _exifString(exifIfd, 0x9286);
      if (fields.contains(MetadataField.exifDate)) result[MetadataField.exifDate.name] = _exifString(exifIfd, 0x0132);
      if (fields.contains(MetadataField.exifDateOriginal)) result[MetadataField.exifDateOriginal.name] = _exifString(exifIfd, 0x9003);
      if (fields.contains(MetadataField.exifDateDigitized)) result[MetadataField.exifDateDigitized.name] = _exifString(exifIfd, 0x9004);
      if (fields.contains(MetadataField.exifGpsLatitude)) result[MetadataField.exifGpsLatitude.name] = _exifString(exif.gpsIfd, 0x0002);
      if (fields.contains(MetadataField.exifGpsLongitude)) result[MetadataField.exifGpsLongitude.name] = _exifString(exif.gpsIfd, 0x0004);
    }
    return result;
  }

  // ── XMP ──

  _XmpInfo? _parseXmp(Uint8List bytes) {
    final xmpString = _extractXmpPacket(bytes);
    if (xmpString == null) return null;
    final title = _xmpSimpleValue(xmpString, 'dc:title');
    final subjects = _xmpBagValues(xmpString, 'dc:subject');
    return _XmpInfo(title: title, subjects: subjects);
  }

  String? _xmpSimpleValue(String xmp, String tag) {
    final matches = RegExp('<$tag>\\s*(.*?)\\s*</$tag>', dotAll: true).firstMatch(xmp);
    if (matches == null) return null;
    var value = matches.group(1)!.trim();
    value = value.replaceAll('<rdf:li>', '').replaceAll('</rdf:li>', '');
    return value;
  }

  List<String>? _xmpBagValues(String xmp, String tag) {
    final match = RegExp('<$tag>\\s*<rdf:Bag>(.*?)</rdf:Bag>\\s*</$tag>', dotAll: true).firstMatch(xmp);
    if (match == null) return null;
    return RegExp(r'<rdf:li>(.*?)</rdf:li>', dotAll: true)
        .allMatches(match.group(1)!)
        .map((m) => m.group(1)!.trim())
        .where((v) => v.isNotEmpty)
        .toList();
  }

  // 从 JPEG/其它二进制中提取 XMP 包（`<x:xmpmeta>` 起始）
  String? _extractXmpPacket(Uint8List bytes) {
    final startMarker = '<x:xmpmeta'.codeUnits;
    final endMarker = '</x:xmpmeta>'.codeUnits;
    final startIndex = _indexOfSequence(bytes, startMarker);
    if (startIndex < 0) return null;
    final endIndex = _indexOfSequence(bytes, endMarker, startIndex);
    if (endIndex < 0) return null;
    final length = endIndex + endMarker.length - startIndex;
    try {
      return utf8.decode(bytes.sublist(startIndex, startIndex + length));
    } catch (_) {
      return null;
    }
  }

  int _indexOfSequence(Uint8List bytes, List<int> seq, [int start = 0]) {
    if (seq.isEmpty || bytes.length < seq.length) return -1;
    for (var i = start; i <= bytes.length - seq.length; i++) {
      var found = true;
      for (var j = 0; j < seq.length; j++) {
        if (bytes[i + j] != seq[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  // ── IPTC ──

  List<Map<String, dynamic>>? _parseIptc(Uint8List bytes) {
    // IPTC IIM 数据段：Photoshop 8BIM 段 (0x08 0x04 0x04 0x00)
    const marker = [0x1c];
    final results = <Map<String, dynamic>>[];
    var index = 0;
    while (index < bytes.length) {
      final idx = _indexOfSequence(bytes, marker, index);
      if (idx < 0 || idx + 1 >= bytes.length) break;
      final record = bytes[idx + 1];
      if (idx + 3 >= bytes.length) break;
      final dataset = bytes[idx + 2];
      final length = bytes[idx + 3] << 8 | bytes[idx + 4];
      if (idx + 5 + length > bytes.length) break;
      final data = bytes.sublist(idx + 5, idx + 5 + length);
      try {
        results.add({
          'record': record,
          'dataset': dataset,
          'value': utf8.decode(data),
        });
      } catch (_) {}
      index = idx + 5 + length;
    }
    return results.isEmpty ? null : results;
  }
}

class _XmpInfo {
  final String? title;
  final List<String>? subjects;
  const _XmpInfo({this.title, this.subjects});
}

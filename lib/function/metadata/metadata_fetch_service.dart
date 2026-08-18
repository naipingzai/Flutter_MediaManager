import 'package:flutter_media_view/function/convert/convert_convert.dart';
import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_multipage.dart';
import 'package:flutter_media_view/function/entry/extensions_props.dart';
import 'package:flutter_media_view/function/media/media_geotiff.dart';
import 'package:flutter_media_view/function/media/panorama.dart';
import 'package:flutter_media_view/function/metadata/catalog.dart';
import 'package:flutter_media_view/function/metadata/overlay.dart';
import 'package:flutter_media_view/function/media/multipage.dart';
import 'package:flutter_media_view/function/common/channel.dart';
import 'package:flutter_media_view/function/common/service_policy.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/function/function_services_metadata_xmp.dart';
import 'package:flutter_media_view/function/utils/time_utils.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class MetadataFetchService {
  // returns Map<Map<Key, Value>> (map of directories, each directory being a map of metadata label and value description)
  Future<Map> getAllMetadata(FmvEntry entry);

  Future<CatalogMetadata?> getCatalogMetadata(FmvEntry entry, {bool background = false});

  Future<OverlayMetadata> getOverlayMetadata(FmvEntry entry, Set<MetadataSyntheticField> fields);

  Future<GeoTiffInfo?> getGeoTiffInfo(FmvEntry entry);

  Future<MultiPageInfo?> getMultiPageInfo(FmvEntry entry);

  Future<PanoramaInfo?> getPanoramaInfo(FmvEntry entry);

  Future<List<Map<String, dynamic>>?> getIptc(FmvEntry entry);

  Future<FmvXmp?> getXmp(FmvEntry entry);

  Future<bool> hasContentResolverProp(String prop);

  Future<String?> getContentResolverProp(FmvEntry entry, String prop);

  Future<DateTime?> getDate(FmvEntry entry, MetadataField field);

  Future<Map<String, Object?>> getFields(FmvEntry entry, Set<MetadataField> fields);
}

class PlatformMetadataFetchService implements MetadataFetchService {
  static const _channel = FmvMethodChannel(FmvChannels.metadataFetch);

  @override
  Future<Map> getAllMetadata(FmvEntry entry) async {
    if (entry.isSvg) return {};

    try {
      final result = await _channel.invokeMethod('getAllMetadata', <String, Object?>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'sizeBytes': entry.sizeBytes,
      });
      if (result != null) return result as Map;
    } on PlatformException catch (e, stack) {
      await _processPlatformException(entry, e, stack);
    }
    return {};
  }

  @override
  Future<CatalogMetadata?> getCatalogMetadata(FmvEntry entry, {bool background = false}) async {
    if (entry.isSvg) return null;

    Future<CatalogMetadata?> call() async {
      try {
        // returns map with:
        // 'mimeType': MIME type as reported by metadata extractors, not Media Store (string)
        // 'dateMillis': date taken in milliseconds since Epoch (long)
        // 'isAnimated': animated gif/webp (bool)
        // 'isFlipped': flipped according to EXIF orientation (bool)
        // 'rating': rating in [-1,5] (int)
        // 'rotationDegrees': rotation degrees according to EXIF orientation or other metadata (int)
        // 'latitude': latitude (double)
        // 'longitude': longitude (double)
        // 'xmpSubjects': ';' separated XMP subjects (string)
        // 'xmpTitle': XMP title (string)
        final result =
            await _channel.invokeMethod('getCatalogMetadata', <String, Object?>{
                  'mimeType': entry.mimeType,
                  'uri': entry.uri,
                  'path': entry.path,
                  'sizeBytes': entry.sizeBytes,
                })
                as Map;
        result['id'] = entry.id;
        FmvEntry.normalizeMimeTypeFields(result);
        return CatalogMetadata.fromMap(result);
      } on PlatformException catch (e, stack) {
        await _processPlatformException(entry, e, stack);
      }
      return null;
    }

    return background
        ? servicePolicy.call(
            call,
            priority: ServiceCallPriority.getMetadata,
          )
        : call();
  }

  @override
  Future<OverlayMetadata> getOverlayMetadata(FmvEntry entry, Set<MetadataSyntheticField> fields) async {
    if (fields.isNotEmpty && !entry.isSvg) {
      try {
        // returns fields on demand, with various value types:
        // 'aperture' (double),
        // 'description' (string)
        // 'exposureTime' (string),
        // 'focalLength' (double),
        // 'iso' (int),
        final result =
            await _channel.invokeMethod('getOverlayMetadata', <String, Object?>{
                  'mimeType': entry.mimeType,
                  'uri': entry.uri,
                  'sizeBytes': entry.sizeBytes,
                  'fields': fields.map((v) => v.toPlatform).toList(),
                })
                as Map;
        return OverlayMetadata.fromMap(result);
      } on PlatformException catch (e, stack) {
        await _processPlatformException(entry, e, stack);
      }
    }
    return const OverlayMetadata();
  }

  @override
  Future<GeoTiffInfo?> getGeoTiffInfo(FmvEntry entry) async {
    try {
      final result =
          await _channel.invokeMethod('getGeoTiffInfo', <String, Object?>{
                'mimeType': entry.mimeType,
                'uri': entry.uri,
                'sizeBytes': entry.sizeBytes,
              })
              as Map;
      return GeoTiffInfo.fromMap(result);
    } on PlatformException catch (e, stack) {
      await _processPlatformException(entry, e, stack);
    }
    return null;
  }

  @override
  Future<MultiPageInfo?> getMultiPageInfo(FmvEntry entry) async {
    try {
      final result = await _channel.invokeMethod('getMultiPageInfo', <String, Object?>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'sizeBytes': entry.sizeBytes,
        'isMotionPhoto': entry.isMotionPhoto,
      });
      final pageMaps = ((result as List?) ?? []).cast<Map>();
      if (entry.isMotionPhoto && pageMaps.isNotEmpty) {
        final imagePage = pageMaps[0];
        imagePage['width'] = entry.width;
        imagePage['height'] = entry.height;
        imagePage['rotationDegrees'] = entry.rotationDegrees;
      }
      pageMaps.forEach(FmvEntry.normalizeMimeTypeFields);
      return MultiPageInfo.fromPageMaps(entry, pageMaps);
    } on PlatformException catch (e, stack) {
      if (e.code != 'getMultiPageInfo-empty') {
        await _processPlatformException(entry, e, stack);
      }
    }
    return null;
  }

  @override
  Future<PanoramaInfo?> getPanoramaInfo(FmvEntry entry) async {
    try {
      // returns map with values for:
      // 'croppedAreaLeft' (int), 'croppedAreaTop' (int), 'croppedAreaWidth' (int), 'croppedAreaHeight' (int),
      // 'fullPanoWidth' (int), 'fullPanoHeight' (int)
      final result =
          await _channel.invokeMethod('getPanoramaInfo', <String, Object?>{
                'mimeType': entry.mimeType,
                'uri': entry.uri,
                'sizeBytes': entry.sizeBytes,
              })
              as Map;
      return PanoramaInfo.fromMap(result);
    } on PlatformException catch (e, stack) {
      await _processPlatformException(entry, e, stack);
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>?> getIptc(FmvEntry entry) async {
    try {
      final result = await _channel.invokeMethod('getIptc', <String, Object?>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
      });
      if (result != null) return (result as List).cast<Map>().map((fields) => fields.cast<String, dynamic>()).toList();
    } on PlatformException catch (e, stack) {
      await _processPlatformException(entry, e, stack);
    }
    return null;
  }

  @override
  Future<FmvXmp?> getXmp(FmvEntry entry) async {
    try {
      final result = await _channel.invokeMethod('getXmp', <String, Object?>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'sizeBytes': entry.sizeBytes,
      });
      if (result != null) return FmvXmp.fromList((result as List).cast<String>());
    } on PlatformException catch (e, stack) {
      await _processPlatformException(entry, e, stack);
    }
    return null;
  }

  final Map<String, bool> _contentResolverProps = {};

  @override
  Future<bool> hasContentResolverProp(String prop) async {
    var exists = _contentResolverProps[prop];
    if (exists != null) return SynchronousFuture(exists);

    try {
      exists = await _channel.invokeMethod('hasContentResolverProp', <String, Object?>{
        'prop': prop,
      });
    } on PlatformException catch (e, stack) {
      await reportService.recordError(e, stack);
    }
    exists ??= false;
    _contentResolverProps[prop] = exists;
    return exists;
  }

  @override
  Future<String?> getContentResolverProp(FmvEntry entry, String prop) async {
    try {
      final result = await _channel.invokeMethod('getContentResolverProp', <String, Object?>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'prop': prop,
      });
      if (result != null) return result as String;
    } on PlatformException catch (e, stack) {
      await _processPlatformException(entry, e, stack);
    }
    return null;
  }

  @override
  Future<DateTime?> getDate(FmvEntry entry, MetadataField field) async {
    try {
      final result = await _channel.invokeMethod('getDate', <String, Object?>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'sizeBytes': entry.sizeBytes,
        'field': field.toPlatform,
      });
      if (result is int) {
        return dateTimeFromMillis(result, isUtc: false);
      }
    } on PlatformException catch (e, stack) {
      await _processPlatformException(entry, e, stack);
    }
    return null;
  }

  @override
  Future<Map<String, Object?>> getFields(FmvEntry entry, Set<MetadataField> fields) async {
    if (fields.isNotEmpty && !entry.isSvg) {
      try {
        final result = await _channel.invokeMethod('getFields', <String, Object?>{
          'mimeType': entry.mimeType,
          'uri': entry.uri,
          'sizeBytes': entry.sizeBytes,
          'fields': fields.map((v) => v.toPlatform).toList(),
        });
        if (result is Map) return result.cast<String, Object?>();
      } on PlatformException catch (e, stack) {
        await _processPlatformException(entry, e, stack);
      }
    }
    return {};
  }

  Future<void> _processPlatformException(FmvEntry entry, PlatformException e, StackTrace stack) async {
    if (entry.isValid) {
      final code = e.code;
      if (code.endsWith('filenotfound')) {
        debugPrint('Unreported `fileNotFound` error with exception=$e');
      } else {
        await reportService.recordError(e, stack);
      }
    }
  }
}

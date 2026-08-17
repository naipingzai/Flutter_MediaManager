import 'dart:async';

import 'package:flutter_media_view/model/entry/entry.dart';
import 'package:flutter_media_view/model/entry/extensions/keys.dart';
import 'package:flutter_media_view/model/entry/extensions/props.dart';
import 'package:flutter_media_view/model/media/geotiff.dart';
import 'package:flutter_media_view/model/media/video/metadata.dart';
import 'package:flutter_media_view/model/metadata/catalog.dart';
import 'package:flutter_media_view/ref/mime_types.dart';
import 'package:flutter_media_view/services/common/services.dart';
import 'package:flutter_media_view/services/metadata/svg_metadata_service.dart';
import 'package:flutter/foundation.dart';

extension ExtraAvesEntryCatalog on AvesEntry {
  Future<void> catalog({required bool background, required bool force, required bool persist}) async {
    if (isCatalogued && !force) return;

    final beforeAvailableHeapSize = await deviceService.getAvailableHeapSize();

    if (isSvg) {
      // vector image sizing is not essential, so we should not spend time for it during loading
      // but it is useful anyway (for aspect ratios etc.) so we size them during cataloguing
      final size = await SvgMetadataService.getSize(this);
      if (size != null) {
        final fields = {
          EntryFields.width: size.width.ceil(),
          EntryFields.height: size.height.ceil(),
        };
        await applyNewFields(fields, persist: persist);
      }
      catalogMetadata = CatalogMetadata(id: id);
    } else {
      // pre-processing
      if (isVideo || mimeType == MimeTypes.avif) {
        // on initial loading, original source may report incorrect size, rotation or duration
        final fields = await VideoMetadataFormatter.getLoadingMetadata(this);
        // check size as the video interpreter may fail on some AVIF stills
        final width = fields[EntryFields.width];
        final height = fields[EntryFields.height];
        final isValid = (width == null || width > 0) && (height == null || height > 0);
        if (isValid) {
          await applyNewFields(fields, persist: persist);
        }
      }

      // cataloguing on platform
      catalogMetadata = await metadataFetchService.getCatalogMetadata(this, background: background);

      // post-processing
      if ((isVideo && (catalogMetadata?.dateMillis ?? 0) == 0) || (mimeType == MimeTypes.avif && durationMillis != null)) {
        final videoMetadata = await VideoMetadataFormatter.completeCatalogMetadata(this);
        if (videoMetadata != null) {
          catalogMetadata = videoMetadata;
        }
      }
      if (isSlowMotion) {
        final (slowMotionFactor, captureDurationMillis) = await videoMetadataFetcher.computeSlowMotionFactorAndDuration(uri: uri, mimeType: mimeType);
        if (slowMotionFactor == 1) {
          // correct false positive derived only from capture FPS
          catalogMetadata = catalogMetadata?.copyWith(isSlowMotion: false);
        } else if (captureDurationMillis != null) {
          durationMillis = captureDurationMillis;
          final fields = {
            EntryFields.durationMillis: captureDurationMillis,
          };
          await applyNewFields(fields, persist: persist);
        }
      }
      if (isGeotiff && !hasGps) {
        final info = await metadataFetchService.getGeoTiffInfo(this);
        if (info != null) {
          final center = GeoTiffCoordinateConverter(
            info: info,
            entry: this,
          ).center;
          if (center != null) {
            catalogMetadata = catalogMetadata?.copyWith(
              latitude: center.latitude,
              longitude: center.longitude,
            );
          }
        }
      }
    }

    final afterAvailableHeapSize = await deviceService.getAvailableHeapSize();
    final diff = beforeAvailableHeapSize - afterAvailableHeapSize;
    const largeHeapUsageThreshold = 15 * (1 << 20); // MiB

    if (diff > largeHeapUsageThreshold) {
      debugPrint('Large heap usage (${diff}B) from cataloguing entry=$this size=$sizeBytes');
      await deviceService.requestGarbageCollection();
    }
  }
}

import 'dart:async';

import 'package:flutter_media_view/function/function_entry.dart';
import 'package:flutter_media_view/function/function_multipage.dart';
import 'package:flutter_media_view/function/function_bursts.dart';
import 'package:flutter_media_view/function/function_common_services.dart';
import 'package:collection/collection.dart';

extension ExtraAvesEntryMultipage on AvesEntry {
  bool get isMultiPage => isStack || ((catalogMetadata?.isMultiPage ?? false) && (isMotionPhoto || !isHdr));

  bool get isStack => stackedEntries?.isNotEmpty == true;

  bool get isMotionPhoto => catalogMetadata?.isMotionPhoto ?? false;

  String? getBurstKey(List<String> patterns) {
    final key = BurstPatterns.getKeyForName(filenameWithoutExtension, patterns);
    return key != null ? '$directory/$key' : null;
  }

  Future<MultiPageInfo?> getMultiPageInfo() async {
    if (isStack) {
      return MultiPageInfo(
        mainEntry: this,
        pages: stackedEntries!
            .mapIndexed(
              (index, entry) => SinglePageInfo(
                index: index,
                pageId: entry.id,
                isDefault: index == 0,
                uri: entry.uri,
                mimeType: entry.mimeType,
                width: entry.width,
                height: entry.height,
                rotationDegrees: entry.rotationDegrees,
                durationMillis: entry.durationMillis,
              ),
            )
            .toList(),
      );
    } else {
      return await metadataFetchService.getMultiPageInfo(this);
    }
  }
}

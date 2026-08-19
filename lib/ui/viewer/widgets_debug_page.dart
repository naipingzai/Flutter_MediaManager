import 'package:flutter_media_view/core/app_mode.dart';
import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_favourites.dart';
import 'package:flutter_media_view/function/entry/extensions_location.dart';
import 'package:flutter_media_view/function/entry/extensions_multipage.dart';
import 'package:flutter_media_view/function/entry/extensions_props.dart';
import 'package:flutter_media_view/ui/viewer/widgets_debug_db.dart';
import 'package:flutter_media_view/ui/viewer/widgets_debug_metadata.dart';
import 'package:flutter_media_view/ui/viewer/widgets_debug_thumbnails.dart';
import 'package:flutter_media_view/ui/viewer/widgets_debug_utils.dart';
import 'package:flutter_media_view/ui/viewer/widgets_info_common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ViewerDebugPage extends StatelessWidget {
  static const routeName = '/viewer/debug';

  final FmvEntry entry;

  const ViewerDebugPage({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <(Tab, Widget)>[
      (const Tab(text: 'Entry'), _buildEntryTabView()),
      if (context.select<ValueNotifier<AppMode>, bool>((vn) => vn.value != .view)) (const Tab(text: 'DB'), DbTab(entry: entry)),
      (const Tab(text: 'Metadata'), MetadataTab(entry: entry)),
      (const Tab(text: 'Thumbs'), ThumbnailsTab(entry: entry)),
    ];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Debug'),
            bottom: TabBar(
              tabs: tabs.map((t) => t.$1).toList(),
            ),
          ),
          body: SafeArea(
            child: TabBarView(
              children: tabs.map((t) => t.$2).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryTabView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoRowGroup(
          info: {
            'hash': '#${shortHash(entry)}',
            'id': '${entry.id}',
            'origin': '${entry.origin}',
            'contentId': '${entry.contentId}',
            'uri': entry.uri,
            'path': entry.path ?? '',
            'directory': entry.directory ?? '',
            'filenameWithoutExtension': entry.filenameWithoutExtension ?? '',
            'extension': entry.extension ?? '',
            'sourceTitle': entry.sourceTitle ?? '',
            'sourceMimeType': entry.sourceMimeType,
            'mimeType': entry.mimeType,
            'isMissingAtPath': '${entry.isMissingAtPath}',
          },
        ),
        const Divider(),
        InfoRowGroup(
          info: {
            'trashed': '${entry.trashed}',
            'trashPath': '${entry.trashDetails?.path}',
            'trashDateMillis': ViewerDebugUtils.toDateValue(entry.trashDetails?.dateMillis),
          },
        ),
        const Divider(),
        InfoRowGroup(
          info: {
            'catalogDateMillis': ViewerDebugUtils.toDateValue(entry.catalogDateMillis),
            'dateAddedSecs': ViewerDebugUtils.toDateValue(entry.dateAddedSecs, factor: 1000),
            'dateModifiedMillis': ViewerDebugUtils.toDateValue(entry.dateModifiedMillis),
            'sourceDateTakenMillis': ViewerDebugUtils.toDateValue(entry.sourceDateTakenMillis),
            'bestDate': '${entry.bestDate}',
          },
        ),
        const Divider(),
        InfoRowGroup(
          info: {
            'width': '${entry.width}',
            'height': '${entry.height}',
            'sourceRotationDegrees': '${entry.sourceRotationDegrees}',
            'rotationDegrees': '${entry.rotationDegrees}',
            'isRotated': '${entry.isRotated}',
            'isFlipped': '${entry.isFlipped}',
            'displayAspectRatio': '${entry.displayAspectRatio}',
            'displaySize': '${entry.displaySize.width}x${entry.displaySize.height}',
          },
        ),
        const Divider(),
        InfoRowGroup(
          info: {
            'durationMillis': '${entry.durationMillis}',
            'durationText': entry.durationText,
          },
        ),
        const Divider(),
        InfoRowGroup(
          info: {
            'sizeBytes': '${entry.sizeBytes}',
            'isFavourite': '${entry.isFavourite}',
            'isSvg': '${entry.isSvg}',
            'isVideo': '${entry.isVideo}',
            'isCatalogued': '${entry.isCatalogued}',
            'is360': '${entry.is360}',
            'isAnimated': '${entry.isAnimated}',
            'isGeotiff': '${entry.isGeotiff}',
            'isHdr': '${entry.isHdr}',
            'isMultiPage': '${entry.isMultiPage}',
            'isMotionPhoto': '${entry.isMotionPhoto}',
            'isSlowMotion': '${entry.isSlowMotion}',
            'canEdit': '${entry.canEdit}',
            'canEditDate': '${entry.canEditDate}',
            'canEditTags': '${entry.canEditTags}',
            'canRotate': '${entry.canRotate}',
            'canFlip': '${entry.canFlip}',
            'tags': '${entry.tags}',
          },
        ),
        const Divider(),
        InfoRowGroup(
          info: {
            'hasGps': '${entry.hasGps}',
            'hasAddress': '${entry.hasAddress}',
            'hasFineAddress': '${entry.hasFineAddress}',
            'latLng': '${entry.latLng}',
          },
        ),
      ],
    );
  }
}

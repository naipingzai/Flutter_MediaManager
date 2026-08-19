import 'dart:collection';

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/model/brand_colors.dart';
import 'package:flutter_media_view/function/metadata/svg_metadata_service.dart';
import 'package:flutter_media_view/ui/theme/colors.dart';
import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/identity/common_identity_fmv_expansion_tile.dart';
import 'package:flutter_media_view/ui/common/identity/common_identity_buttons_outlined_button.dart';
import 'package:flutter_media_view/ui/viewer/info/common.dart';
import 'package:flutter_media_view/ui/viewer/info/embedded_notifications.dart';
import 'package:flutter_media_view/ui/viewer/info/metadata_geotiff.dart';
import 'package:flutter_media_view/ui/viewer/info/metadata_dir.dart';
import 'package:flutter_media_view/ui/viewer/info/metadata_thumbnail.dart';
import 'package:flutter_media_view/ui/viewer/info/metadata_xmp_tile.dart';
import 'package:flutter_media_view/ui/viewer/source_viewer_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MetadataDirTile extends StatelessWidget {
  final FmvEntry entry;
  final String title;
  final MetadataDirectory dir;
  final ValueNotifier<String?>? expandedDirectoryNotifier;
  final bool initiallyExpanded, showThumbnails;

  const MetadataDirTile({
    super.key,
    required this.entry,
    required this.title,
    required this.dir,
    this.expandedDirectoryNotifier,
    this.initiallyExpanded = false,
    this.showThumbnails = true,
  });

  @override
  Widget build(BuildContext context) {
    var tags = dir.tags;
    if (tags.isEmpty) return const SizedBox();

    return FmvExpansionTile(
      title: title,
      highlightColor: getTitleColor(context, dir),
      expandedNotifier: expandedDirectoryNotifier,
      initiallyExpanded: initiallyExpanded,
      children: [
        MetadataDirTileBody(
          entry: entry,
          dir: dir,
          showThumbnails: showThumbnails,
        ),
      ],
    );
  }

  static Color getTitleColor(BuildContext context, MetadataDirectory dir) {
    final dirName = dir.name;
    if (dirName == MetadataDirectory.xmpDirectory) {
      return context.select<FmvColorsData, Color>((v) => v.xmp);
    } else {
      final colors = context.watch<FmvColorsData>();
      return dir.color ?? colors.fromBrandColor(BrandColors.get(dirName)) ?? colors.fromString(dirName);
    }
  }
}

class MetadataDirTileBody extends StatelessWidget {
  final FmvEntry entry;
  final MetadataDirectory dir;
  final bool showThumbnails;

  const MetadataDirTileBody({
    super.key,
    required this.entry,
    required this.dir,
    this.showThumbnails = true,
  });

  @override
  Widget build(BuildContext context) {
    var tags = dir.tags;

    late final List<Widget> children;
    final dirName = dir.name;
    if (dirName == MetadataDirectory.xmpDirectory) {
      children = [
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
          child: XmpDirTileBody(
            allTags: dir.allTags,
            tags: tags,
          ),
        ),
      ];
    } else {
      Map<String, InfoValueSpanBuilder>? linkHandlers;
      switch (dirName) {
        case SvgMetadataService.metadataDirectory:
          linkHandlers = getSvgLinkHandlers(tags);
        case MetadataDirectory.coverDirectory:
          linkHandlers = getVideoCoverLinkHandlers(tags);
        case MetadataDirectory.geoTiffDirectory:
          tags = SplayTreeMap.from(
            tags.map((name, value) {
              final tag = GeoTiffDirectory.tagForName(name);
              return MapEntry(name, GeoTiffDirectory.formatValue(tag, value));
            }),
          );
      }

      children = [
        if (showThumbnails && dirName == MetadataDirectory.exifThumbnailDirectory) MetadataThumbnails(entry: entry),
        if (dirName.startsWith(MetadataDirectory.mpfImageDirectoryPrefix))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FmvOutlinedButton(
              label: context.l10n.viewerInfoOpenLinkText,
              onPressed: () {
                final id = int.tryParse(dirName.substring(MetadataDirectory.mpfImageDirectoryPrefix.length));
                if (id != null) {
                  OpenEmbeddedDataNotification.mpf(id).dispatch(context);
                }
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
          child: InfoRowGroup(
            info: tags,
            spanBuilders: linkHandlers,
          ),
        ),
      ];
    }

    return Column(
      crossAxisAlignment: .start,
      children: children,
    );
  }

  static Map<String, InfoValueSpanBuilder> getSvgLinkHandlers(SplayTreeMap<String, String> tags) {
    return {
      'Metadata': InfoRowGroup.linkSpanBuilder(
        linkText: (context) => context.l10n.viewerInfoViewXmlLinkText,
        onTap: (context) {
          Navigator.maybeOf(context)?.push(
            MaterialPageRoute(
              settings: const RouteSettings(name: SourceViewerPage.routeName),
              builder: (context) => SourceViewerPage(
                loader: () => SynchronousFuture(tags['Metadata'] ?? ''),
              ),
            ),
          );
        },
      ),
    };
  }

  static Map<String, InfoValueSpanBuilder> getVideoCoverLinkHandlers(SplayTreeMap<String, String> tags) {
    return {
      'Image': InfoRowGroup.linkSpanBuilder(
        linkText: (context) => context.l10n.viewerInfoOpenLinkText,
        onTap: (context) => OpenEmbeddedDataNotification.videoCover().dispatch(context),
      ),
    };
  }
}

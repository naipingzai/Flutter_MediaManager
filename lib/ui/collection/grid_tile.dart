import 'package:flutter_media_view/core/app_mode.dart';
import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/model/function_selection.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/function/services/intent_service.dart';
import 'package:flutter_media_view/ui/collection/grid_list_details.dart';
import 'package:flutter_media_view/ui/collection/grid_list_details_theme.dart';
import 'package:flutter_media_view/ui/common/common_grid_scaling.dart';
import 'package:flutter_media_view/ui/viewer/common_providers_entry_provider.dart';
import 'package:flutter_media_view/ui/common/thumbnails/common_thumbnail_decorated.dart';
import 'package:flutter_media_view/ui/common/thumbnails/common_thumbnail_notifications.dart';
import 'package:flutter_media_view/ui/viewer/viewer_hero.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class InteractiveTile extends StatelessWidget {
  final CollectionLens collection;
  final FmvEntry entry;
  final double thumbnailExtent;
  final TileLayout tileLayout;
  final ValueNotifier<bool>? isScrollingNotifier;

  const InteractiveTile({
    super.key,
    required this.collection,
    required this.entry,
    required this.thumbnailExtent,
    required this.tileLayout,
    this.isScrollingNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final appMode = context.read<ValueNotifier<AppMode>>().value;
        switch (appMode) {
          case .main:
            final selection = context.read<Selection<FmvEntry>>();
            if (selection.isSelecting) {
              selection.toggleSelection(entry);
            } else {
              OpenViewerNotification(entry).dispatch(context);
            }
          case .pickSingleMediaExternal:
            IntentService.submitPickedItems([entry.uri]);
          case .pickMultipleMediaExternal:
            final selection = context.read<Selection<FmvEntry>>();
            selection.toggleSelection(entry);
          case .pickFilteredMediaInternal:
          case .pickUnfilteredMediaInternal:
            Navigator.maybeOf(context)?.pop<FmvEntry>(entry);
          default:
            break;
        }
      },
      child: MetaData(
        metaData: ScalerMetadata(entry),
        child: Tile(
          entry: entry,
          thumbnailExtent: thumbnailExtent,
          tileLayout: tileLayout,
          selectable: true,
          highlightable: true,
          isScrollingNotifier: isScrollingNotifier,
          heroTagger: () => EntryHeroInfo(collection, entry).tag,
        ),
      ),
    );
  }
}

class Tile extends StatelessWidget {
  final FmvEntry entry;
  final double thumbnailExtent;
  final TileLayout tileLayout;
  final bool selectable, highlightable;
  final ValueNotifier<bool>? isScrollingNotifier;
  final Object? Function()? heroTagger;

  const Tile({
    super.key,
    required this.entry,
    required this.thumbnailExtent,
    required this.tileLayout,
    this.selectable = false,
    this.highlightable = false,
    this.isScrollingNotifier,
    this.heroTagger,
  });

  @override
  Widget build(BuildContext context) {
    switch (tileLayout) {
      case .mosaic:
      case .grid:
        return _buildThumbnail();
      case .list:
        return Row(
          crossAxisAlignment: .stretch,
          children: [
            SizedBox.square(
              dimension: context.select<EntryListDetailsThemeData, double>((v) => v.extent),
              child: _buildThumbnail(),
            ),
            Expanded(
              child: EntryListDetails(
                entry: entry,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildThumbnail() => DecoratedThumbnail(
    entry: entry,
    tileExtent: thumbnailExtent,
    isMosaic: tileLayout == TileLayout.mosaic,
    // when the user is scrolling faster than we can retrieve the thumbnails,
    // the retrieval task queue can pile up for thumbnails that got disposed
    // in this case we pause the image retrieval task to get it out of the queue
    cancellableNotifier: isScrollingNotifier,
    selectable: selectable,
    highlightable: highlightable,
    heroTagger: heroTagger,
    // do not use a hero placeholder but hide the thumbnail matching the viewer entry,
    // so that it can hero out on an entry and come back with a hero to a different entry
    heroPlaceholderBuilder: (context, heroSize, child) => child,
    imageDecorator: (context, child) {
      return Selector<ViewerEntryNotifier, bool>(
        selector: (context, v) => v.value == entry,
        builder: (context, isViewerEntry, child) {
          return Visibility.maintain(
            visible: !isViewerEntry,
            child: child!,
          );
        },
        child: child,
      );
    },
  );
}

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view/function/utils/debouncer.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/identity/common_identity_empty.dart';
import 'package:flutter_media_view/ui/common/thumbnails/common_thumbnail_scroller.dart';
import 'package:flutter_media_view/ui/common/map_info_row.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_hero.dart';
import 'package:fmv_utils/flutter_media_view_utils.dart';
import 'package:flutter/material.dart';

class MapEntryScroller extends StatefulWidget {
  final ValueNotifier<CollectionLens?> regionCollectionNotifier;
  final ValueNotifier<FmvEntry?> dotEntryNotifier;
  final ValueNotifier<int?> selectedIndexNotifier;
  final void Function(int index) onTap;

  const MapEntryScroller({
    super.key,
    required this.regionCollectionNotifier,
    required this.dotEntryNotifier,
    required this.selectedIndexNotifier,
    required this.onTap,
  });

  @override
  State<MapEntryScroller> createState() => _MapEntryScrollerState();
}

class _MapEntryScrollerState extends State<MapEntryScroller> {
  final ValueNotifier<FmvEntry?> _infoEntryNotifier = ValueNotifier(null);
  final Debouncer _infoDebouncer = Debouncer(delay: ADurations.mapInfoDebounceDelay);

  @override
  void initState() {
    super.initState();
    _registerWidget(widget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSelectedEntryChanged());
  }

  @override
  void didUpdateWidget(covariant MapEntryScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
  }

  @override
  void dispose() {
    _infoEntryNotifier.dispose();
    _unregisterWidget(widget);
    super.dispose();
  }

  void _registerWidget(MapEntryScroller widget) {
    widget.dotEntryNotifier.addListener(_onSelectedEntryChanged);
  }

  void _unregisterWidget(MapEntryScroller widget) {
    widget.dotEntryNotifier.removeListener(_onSelectedEntryChanged);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: .start,
          children: [
            SafeArea(
              top: false,
              bottom: false,
              child: MapInfoRow(entryNotifier: _infoEntryNotifier),
            ),
            const SizedBox(height: 8),
            NullableValueListenableBuilder<CollectionLens?>(
              valueListenable: widget.regionCollectionNotifier,
              builder: (context, regionCollection, child) {
                // update when entries are added/removed
                final regionEntries = regionCollection?.sortedEntries ?? [];
                return ThumbnailScroller(
                  availableWidth: MediaQuery.sizeOf(context).width,
                  entryCount: regionEntries.length,
                  entryBuilder: (index) => index < regionEntries.length ? regionEntries[index] : null,
                  indexNotifier: widget.selectedIndexNotifier,
                  onTap: widget.onTap,
                  heroTagger: (entry) => EntryHeroInfo(regionCollection, entry).tag,
                  highlightable: true,
                  showLocation: false,
                );
              },
            ),
          ],
        ),
        Positioned.fill(
          child: ValueListenableBuilder<FmvEntry?>(
            valueListenable: _infoEntryNotifier,
            builder: (context, infoEntry, child) {
              return ValueListenableBuilder<CollectionLens?>(
                valueListenable: widget.regionCollectionNotifier,
                builder: (context, regionCollection, child) {
                  return infoEntry == null && regionCollection != null && regionCollection.isEmpty
                      ? EmptyContent(
                          text: context.l10n.mapEmptyRegion,
                          alignment: Alignment.center,
                          fontSize: 18,
                        )
                      : const SizedBox();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _onSelectedEntryChanged() {
    final selectedEntry = widget.dotEntryNotifier.value;
    if (_infoEntryNotifier.value == null || selectedEntry == null) {
      _infoEntryNotifier.value = selectedEntry;
    } else {
      _infoDebouncer(() => _infoEntryNotifier.value = selectedEntry);
    }
  }
}

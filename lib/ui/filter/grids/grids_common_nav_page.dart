import 'package:flutter_media_view/function/filters/container_album_group.dart';
import 'package:flutter_media_view/function/filters/container_group_base.dart';
import 'package:flutter_media_view/function/filters/covered_stored_album.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/model/function_selection.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_source.dart';
import 'package:flutter_media_view/function/utils/time_utils.dart';
import 'package:flutter_media_view/ui/collection/collection_page.dart';
import 'package:flutter_media_view/ui/common/actions/common_action_mixins_feedback.dart';
import 'package:flutter_media_view/ui/common/actions/common_action_mixins_vault_aware.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/filter/common_identity_fmv_filter_chip.dart';
import 'package:flutter_media_view/ui/filter/common_providers_group_provider.dart';
import 'package:flutter_media_view/ui/common/common_providers_query_provider.dart';
import 'package:flutter_media_view/ui/common/common_providers_selection_provider.dart';
import 'package:flutter_media_view/ui/filter/grids/grids_common_action_delegates_chip_set.dart';
import 'package:flutter_media_view/ui/filter/grids/grids_common_app_bar.dart';
import 'package:flutter_media_view/ui/filter/grids/grids_common_grid_page.dart';
import 'package:flutter_media_view/ui/filter/grids/grids_common_section_keys.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FilterNavigationPage<T extends CollectionFilter, CSAD extends ChipSetActionDelegate<T>> extends StatefulWidget {
  final CollectionSource source;
  final String title;
  final ChipSortFactor sortFactor;
  final bool showHeaders;
  final CSAD actionDelegate;
  final Map<ChipSectionKey, List<FilterGridItem<T>>> filterSections;
  final Set<T>? newFilters;
  final Widget Function() emptyBuilder;

  const FilterNavigationPage({
    super.key,
    required this.source,
    required this.title,
    required this.sortFactor,
    this.showHeaders = false,
    required this.actionDelegate,
    required this.filterSections,
    this.newFilters,
    required this.emptyBuilder,
  });

  @override
  State<FilterNavigationPage<T, CSAD>> createState() => _FilterNavigationPageState<T, CSAD>();

  static int compareFiltersByDate(FilterGridItem<CollectionFilter> a, FilterGridItem<CollectionFilter> b) {
    final c = (b.entry?.bestDate ?? epoch).compareTo(a.entry?.bestDate ?? epoch);
    return c != 0 ? c : a.filter.compareTo(b.filter);
  }

  static int compareFiltersByEntryCount(MapEntry<CollectionFilter, num> a, MapEntry<CollectionFilter, num> b) {
    final c = b.value.compareTo(a.value);
    return c != 0 ? c : a.key.compareTo(b.key);
  }

  static int compareFiltersBySize(MapEntry<CollectionFilter, num> a, MapEntry<CollectionFilter, num> b) {
    final c = b.value.compareTo(a.value);
    return c != 0 ? c : a.key.compareTo(b.key);
  }

  static int compareFiltersByName(FilterGridItem<CollectionFilter> a, FilterGridItem<CollectionFilter> b) {
    // assume we compare context-independent labels
    return compareAsciiUpperCaseNatural(a.filter.universalLabel, b.filter.universalLabel);
  }

  static int compareFiltersByPath<T extends CollectionFilter>(FilterGridItem<T> a, FilterGridItem<T> b) {
    if (T == AlbumBaseFilter) {
      final filterA = a.filter;
      final filterB = b.filter;
      final pathA = filterA is StoredAlbumFilter ? filterA.album : '';
      final pathB = filterB is StoredAlbumFilter ? filterB.album : '';
      final c = pathA.compareTo(pathB);
      return c != 0 ? c : a.filter.compareTo(b.filter);
    }
    return 0;
  }

  static List<FilterGridItem<T>> sort<T extends CollectionFilter, CSAD extends ChipSetActionDelegate<T>>(
    ChipSortFactor sortFactor,
    bool reverse,
    CollectionSource source,
    Set<T> filters,
  ) {
    List<FilterGridItem<T>> toGridItem(CollectionSource source, Set<T> filters) {
      return filters
          .map(
            (filter) => FilterGridItem(
              filter,
              source.recentEntry(filter),
            ),
          )
          .toList();
    }

    List<FilterGridItem<T>> allMapEntries = [];
    switch (sortFactor) {
      case .name:
        allMapEntries = toGridItem(source, filters)..sort(compareFiltersByName);
      case .date:
        allMapEntries = toGridItem(source, filters)..sort(compareFiltersByDate);
      case .count:
        final filtersWithCount = List.of(filters.map((filter) => MapEntry(filter, source.count(filter))));
        filtersWithCount.sort(compareFiltersByEntryCount);
        filters = filtersWithCount.map((kv) => kv.key).toSet();
        allMapEntries = toGridItem(source, filters);
      case .size:
        final filtersWithSize = List.of(filters.map((filter) => MapEntry(filter, source.size(filter))));
        filtersWithSize.sort(compareFiltersBySize);
        filters = filtersWithSize.map((kv) => kv.key).toSet();
        allMapEntries = toGridItem(source, filters);
      case .path:
        allMapEntries = toGridItem(source, filters)..sort(compareFiltersByPath);
    }
    if (reverse) {
      allMapEntries = allMapEntries.reversed.toList();
    }
    return allMapEntries;
  }
}

class _FilterNavigationPageState<T extends CollectionFilter, CSAD extends ChipSetActionDelegate<T>> extends State<FilterNavigationPage<T, CSAD>> with FeedbackMixin, VaultAwareMixin {
  final ValueNotifier<double> _appBarHeightNotifier = ValueNotifier(0);

  @override
  void dispose() {
    _appBarHeightNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionProvider<FilterGridItem<T>>(
      child: Builder(
        builder: (context) {
          final animate = context.select<Settings, bool>((v) => v.animate);
          final scrollController = PrimaryScrollController.of(context);
          return QueryProvider(
            startEnabled: settings.getShowTitleQuery(context.currentRouteName!),
            child: FilterGridPage<T>(
              appBar: FilterGridAppBar<T, CSAD>(
                source: widget.source,
                title: widget.title,
                actionDelegate: widget.actionDelegate,
                appBarHeightNotifier: _appBarHeightNotifier,
                scrollController: scrollController,
                onGroupCrumbTap: (context, filter) {
                  final selection = context.read<Selection<FilterGridItem<T>>?>();
                  if (selection == null || !selection.isSelecting) {
                    Navigator.maybeOf(context)?.push(_buildCollectionPageRoute(filter));
                  }
                },
              ),
              appBarHeightNotifier: _appBarHeightNotifier,
              scrollController: scrollController,
              sections: widget.filterSections,
              newFilters: widget.newFilters ?? {},
              sortFactor: widget.sortFactor,
              showHeaders: widget.showHeaders,
              selectable: true,
              emptyBuilder: () => ValueListenableBuilder<SourceState>(
                valueListenable: widget.source.stateNotifier,
                builder: (context, sourceState, child) {
                  return sourceState != SourceState.loading ? widget.emptyBuilder() : const SizedBox();
                },
              ),
              // do not always enable hero, otherwise unwanted hero gets triggered
              // when using `Show in [...]` action from a chip in the Collection filter bar
              heroType: animate ? HeroType.onTap : HeroType.never,
              onTileTap: (gridItem, navigate) async {
                final selection = context.read<Selection<FilterGridItem<T>>?>();
                if (selection != null && selection.isSelecting) {
                  selection.toggleSelection(gridItem);
                } else {
                  final filter = gridItem.filter;
                  if (!await unlockFilter(context, filter)) return;

                  if (filter is GroupBaseFilter) {
                    context.read<FilterGroupNotifier>().value = filter.uri;
                  } else {
                    navigate(_buildCollectionPageRoute(filter));
                  }
                }
              },
            ),
          );
        },
      ),
    );
  }

  Route _buildCollectionPageRoute(CollectionFilter filter) {
    return MaterialPageRoute(
      settings: const RouteSettings(name: CollectionPage.routeName),
      builder: (context) => CollectionPage(
        source: context.read<CollectionSource>(),
        filters: {filter},
      ),
    );
  }
}

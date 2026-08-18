import 'package:flutter_media_view/function/function_states.dart';
import 'package:flutter_media_view/function/filters/covered_location.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_source.dart';
import 'package:flutter_media_view/function/source/location_place.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/common_identity_empty.dart';
import 'package:flutter_media_view/ui/filter/widgets_filter_grids_common_action_delegates_state_set.dart';
import 'package:flutter_media_view/ui/filter/widgets_filter_grids_common_filter_nav_page.dart';
import 'package:flutter_media_view/ui/filter/widgets_filter_grids_common_section_keys.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StateListPage extends StatelessWidget {
  static const routeName = '/states';

  final Set<String> countryCodes;

  const StateListPage({
    super.key,
    required this.countryCodes,
  });

  @override
  Widget build(BuildContext context) {
    final source = context.read<CollectionSource>();
    return Selector<Settings, (ChipSortFactor, bool, Set<CollectionFilter>)>(
      selector: (context, s) => (s.stateSortFactor, s.stateSortReverse, s.pinnedFilters),
      shouldRebuild: (t1, t2) {
        // `Selector` by default uses `DeepCollectionEquality`, which does not go deep in collections within records
        const eq = DeepCollectionEquality();
        return !(eq.equals(t1.$1, t2.$1) && eq.equals(t1.$2, t2.$2) && eq.equals(t1.$3, t2.$3));
      },
      builder: (context, s, child) {
        return StreamBuilder(
          stream: source.eventBus.on<PlacesChangedEvent>(),
          builder: (context, snapshot) {
            final gridItems = _getGridItems(source);
            return FilterNavigationPage<LocationFilter, StateChipSetActionDelegate>(
              source: source,
              title: context.l10n.statePageTitle,
              sortFactor: settings.stateSortFactor,
              actionDelegate: StateChipSetActionDelegate(gridItems),
              filterSections: _groupToSections(gridItems),
              emptyBuilder: () => EmptyContent(
                icon: AIcons.state,
                text: context.l10n.stateEmpty,
              ),
            );
          },
        );
      },
    );
  }

  List<FilterGridItem<LocationFilter>> _getGridItems(CollectionSource source) {
    final selectedStateCodes = countryCodes.expand((v) => GeoStates.stateCodesByCountryCode[v] ?? <String>{}).toSet();
    final filters = source.sortedStates.where((v) => selectedStateCodes.any(v.endsWith)).map((location) => LocationFilter(LocationLevel.state, location)).toSet();

    return FilterNavigationPage.sort(settings.stateSortFactor, settings.stateSortReverse, source, filters);
  }

  static Map<ChipSectionKey, List<FilterGridItem<LocationFilter>>> _groupToSections(Iterable<FilterGridItem<LocationFilter>> sortedMapEntries) {
    final pinned = settings.pinnedFilters.whereType<LocationFilter>();
    final byPin = groupBy<FilterGridItem<LocationFilter>, bool>(sortedMapEntries, (e) => pinned.contains(e.filter));
    final pinnedMapEntries = (byPin[true] ?? []);
    final unpinnedMapEntries = (byPin[false] ?? []);

    return {
      if (pinnedMapEntries.isNotEmpty || unpinnedMapEntries.isNotEmpty)
        const ChipSectionKey(): [
          ...pinnedMapEntries,
          ...unpinnedMapEntries,
        ],
    };
  }
}

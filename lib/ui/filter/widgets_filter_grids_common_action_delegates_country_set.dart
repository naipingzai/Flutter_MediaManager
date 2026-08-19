import 'package:flutter_media_view/core/app_mode.dart';
import 'package:flutter_media_view/function/geo/function_states.dart';
import 'package:flutter_media_view/function/filters/covered_location.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/filter/widgets_filter_grids_common_action_delegates_chip_set.dart';
import 'package:flutter_media_view/ui/filter/widgets_filter_grids_countries_page.dart';
import 'package:flutter_media_view/ui/filter/widgets_filter_grids_states_page.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

class CountryChipSetActionDelegate extends ChipSetActionDelegate<LocationFilter> {
  final Iterable<FilterGridItem<LocationFilter>> _items;

  CountryChipSetActionDelegate(Iterable<FilterGridItem<LocationFilter>> items) : _items = items;

  @override
  Iterable<FilterGridItem<LocationFilter>> get allItems => _items;

  @override
  ChipSortFactor get sortFactor => settings.countrySortFactor;

  @override
  set sortFactor(ChipSortFactor factor) => settings.countrySortFactor = factor;

  @override
  bool get sortReverse => settings.countrySortReverse;

  @override
  set sortReverse(bool value) => settings.countrySortReverse = value;

  @override
  TileLayout get tileLayout => settings.getTileLayout(CountryListPage.routeName);

  @override
  set tileLayout(TileLayout tileLayout) => settings.setTileLayout(CountryListPage.routeName, tileLayout);

  @override
  bool isVisible(
    ChipSetAction action, {
    required AppMode appMode,
    required bool isSelecting,
    required int itemCount,
    required Set<LocationFilter> selectedFilters,
  }) {
    switch (action) {
      case .showCountryStates:
        return isSelecting;
      default:
        return super.isVisible(
          action,
          appMode: appMode,
          isSelecting: isSelecting,
          itemCount: itemCount,
          selectedFilters: selectedFilters,
        );
    }
  }

  @override
  bool canApply(
    ChipSetAction action, {
    required bool isSelecting,
    required int itemCount,
    required Set<LocationFilter> selectedFilters,
  }) {
    switch (action) {
      case .showCountryStates:
        return selectedFilters.any((v) => GeoStates.stateCountryCodes.contains(v.code));
      default:
        return super.canApply(
          action,
          isSelecting: isSelecting,
          itemCount: itemCount,
          selectedFilters: selectedFilters,
        );
    }
  }

  @override
  void onActionSelected(BuildContext context, ChipSetAction action) {
    reportService.log('$runtimeType handles $action');
    switch (action) {
      // single/multiple filters
      case .showCountryStates:
        _showStates(context);
        browse(context);
      default:
        break;
    }
    super.onActionSelected(context, action);
  }

  void _showStates(BuildContext context) {
    final filters = getSelectedFilters(context);
    final countryCodes = filters.map((v) => v.code).where(GeoStates.stateCountryCodes.contains).nonNulls.toSet();
    Navigator.maybeOf(context)?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: StateListPage.routeName),
        builder: (_) => StateListPage(countryCodes: countryCodes),
      ),
    );
  }
}

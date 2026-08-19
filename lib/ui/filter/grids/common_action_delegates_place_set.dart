import 'package:flutter_media_view/function/filters/covered_location.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/filter/grids/common_action_delegates_chip_set.dart';
import 'package:flutter_media_view/ui/filter/grids/places_page.dart';
import 'package:fmv_model/flutter_media_view_model.dart';

class PlaceChipSetActionDelegate extends ChipSetActionDelegate<LocationFilter> {
  final Iterable<FilterGridItem<LocationFilter>> _items;

  PlaceChipSetActionDelegate(Iterable<FilterGridItem<LocationFilter>> items) : _items = items;

  @override
  Iterable<FilterGridItem<LocationFilter>> get allItems => _items;

  @override
  ChipSortFactor get sortFactor => settings.placeSortFactor;

  @override
  set sortFactor(ChipSortFactor factor) => settings.placeSortFactor = factor;

  @override
  bool get sortReverse => settings.placeSortReverse;

  @override
  set sortReverse(bool value) => settings.placeSortReverse = value;

  @override
  TileLayout get tileLayout => settings.getTileLayout(PlaceListPage.routeName);

  @override
  set tileLayout(TileLayout tileLayout) => settings.setTileLayout(PlaceListPage.routeName, tileLayout);
}

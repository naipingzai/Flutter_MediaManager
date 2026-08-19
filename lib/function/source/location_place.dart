import 'package:fmv/function/entry/entry.dart';
import 'package:fmv/function/filters/covered_location.dart';
import 'package:fmv/function/source/collection_source.dart';
import 'package:fmv_utils/flutter_media_view_utils.dart';
import 'package:collection/collection.dart';

mixin PlaceMixin on SourceBase {
  // by place
  final Map<String, int> _filterEntryCountMap = {}, _filterSizeMap = {};
  final Map<String, FmvEntry?> _filterRecentEntryMap = {};

  void invalidatePlaceFilterSummary({
    Set<FmvEntry>? entries,
    Set<String>? places,
    bool notify = true,
  }) {
    if (_filterEntryCountMap.isEmpty && _filterSizeMap.isEmpty && _filterRecentEntryMap.isEmpty) return;

    if (entries == null && places == null) {
      _filterEntryCountMap.clear();
      _filterSizeMap.clear();
      _filterRecentEntryMap.clear();
    } else {
      places ??= {};
      if (entries != null) {
        places.addAll(entries.map((entry) => entry.addressDetails?.place).nonNulls);
      }
      places.forEach((place) {
        _filterEntryCountMap.remove(place);
        _filterSizeMap.remove(place);
        _filterRecentEntryMap.remove(place);
      });
    }
    if (notify) {
      eventBus.fire(PlaceSummaryInvalidatedEvent(places));
    }
  }

  int placeEntryCount(LocationFilter filter) {
    return _filterEntryCountMap.putIfAbsent(filter.place, () => visibleEntries.where(filter.test).length);
  }

  int placeSize(LocationFilter filter) {
    return _filterSizeMap.putIfAbsent(filter.place, () => visibleEntries.where(filter.test).map((v) => v.sizeBytes).sum);
  }

  FmvEntry? placeRecentEntry(LocationFilter filter) {
    return _filterRecentEntryMap.putIfAbsent(filter.place, () => sortedEntriesByDate.firstWhereOrNull(filter.test));
  }
}

class PlacesChangedEvent {}

class PlaceSummaryInvalidatedEvent {
  final Set<String>? places;

  const PlaceSummaryInvalidatedEvent(this.places);
}

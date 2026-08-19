import 'dart:async';

import 'package:flutter_media_view/function/model/covers.dart';
import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_catalog.dart';
import 'package:flutter_media_view/function/entry/extensions_keys.dart';
import 'package:flutter_media_view/function/entry/extensions_location.dart';
import 'package:flutter_media_view/function/entry/extensions_props.dart';
import 'package:flutter_media_view/function/entry/sort.dart';
import 'package:flutter_media_view/function/model/favourites.dart';
import 'package:flutter_media_view/function/filters/container_album_group.dart';
import 'package:flutter_media_view/function/filters/container_tag_group.dart';
import 'package:flutter_media_view/function/filters/covered_location.dart';
import 'package:flutter_media_view/function/filters/covered_stored_album.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/filters/filters_trash.dart';
import 'package:flutter_media_view/function/grouping/common.dart';
import 'package:flutter_media_view/function/grouping/grouping_convert.dart';
import 'package:flutter_media_view/function/metadata/metadata_trash.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/album.dart';
import 'package:flutter_media_view/function/source/analysis_controller.dart';
import 'package:flutter_media_view/function/source/events.dart';
import 'package:flutter_media_view/function/source/location_country.dart';
import 'package:flutter_media_view/function/source/location.dart';
import 'package:flutter_media_view/function/source/location_place.dart';
import 'package:flutter_media_view/function/source/location_state.dart';
import 'package:flutter_media_view/function/source/tag.dart';
import 'package:flutter_media_view/function/source/source_trash.dart';
import 'package:flutter_media_view/function/function_vaults.dart';
import 'package:flutter_media_view/function/services/analysis_service.dart';
import 'package:flutter_media_view/function/common/image_op_events.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/common/fmv_app.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:collection/collection.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';
import 'package:leak_tracker/leak_tracker.dart';

typedef SourceScope = Set<CollectionFilter>?;

mixin SourceBase {
  EventBus get eventBus;

  FmvEntry? getEntryById(int id);

  Set<FmvEntry> get allEntries;

  Set<FmvEntry> get visibleEntries;

  Set<FmvEntry> get trashedEntries;

  List<FmvEntry> get sortedEntriesByDate;

  ValueNotifier<SourceState> stateNotifier = ValueNotifier(SourceState.ready);

  set state(SourceState value) => stateNotifier.value = value;

  SourceState get state => stateNotifier.value;

  bool get isReady => state == SourceState.ready;

  ValueNotifier<ProgressEvent> progressNotifier = ValueNotifier(const ProgressEvent(done: 0, total: 0));

  void setProgress({required int done, required int total}) => progressNotifier.value = ProgressEvent(done: done, total: total);

  void invalidateEntries();
}

abstract class CollectionSource with SourceBase, AlbumMixin, CountryMixin, PlaceMixin, StateMixin, LocationMixin, TagMixin, TrashMixin {
  static const fullScope = <CollectionFilter>{};

  CollectionSource() {
    if (kFlutterMemoryAllocationsEnabled) {
      LeakTracking.dispatchObjectCreated(
        library: 'fmv',
        className: '$CollectionSource',
        object: this,
      );
    }
    settings.updateStream.where((event) => event.key == SettingKeys.localeKey).listen((_) => invalidateStoredAlbumDisplayNames());
    settings.updateStream.where((event) => event.key == SettingKeys.hiddenFiltersKey).listen((event) {
      final oldValue = event.oldValue;
      if (oldValue is List?) {
        final oldHiddenFilters = (oldValue ?? []).map(CollectionFilter.fromJson).nonNulls.toSet();
        final newlyVisibleFilters = oldHiddenFilters.whereNot(settings.hiddenFilters.contains).toSet();
        _onFilterVisibilityChanged(newlyVisibleFilters);
      }
    });
    vaults.lockStateChangeNotifier.addListener(_onVaultsChanged);
  }

  @mustCallSuper
  void dispose() {
    if (kFlutterMemoryAllocationsEnabled) {
      LeakTracking.dispatchObjectDisposed(object: this);
    }
    stateNotifier.dispose();
    progressNotifier.dispose();
    vaults.lockStateChangeNotifier.removeListener(_onVaultsChanged);
    _disposeAllEntries();
  }

  set canAnalyze(bool enabled);

  final EventBus _eventBus = EventBus();

  @override
  EventBus get eventBus => _eventBus;

  @override
  FmvEntry? getEntryById(int id) => _entriesById[id];

  final Map<int, FmvEntry> _entriesById = {};

  @override
  Set<FmvEntry> get allEntries => Set.unmodifiable(_entriesById.values);

  Set<FmvEntry>? _visibleEntries, _trashedEntries;

  @override
  Set<FmvEntry> get visibleEntries {
    _visibleEntries ??= Set.unmodifiable(_applyHiddenFilters(_entriesById.values));
    return _visibleEntries!;
  }

  @override
  Set<FmvEntry> get trashedEntries {
    _trashedEntries ??= Set.unmodifiable(_applyTrashFilter(_entriesById.values));
    return _trashedEntries!;
  }

  List<FmvEntry>? _sortedEntriesByDate;

  @override
  List<FmvEntry> get sortedEntriesByDate {
    _sortedEntriesByDate ??= List.unmodifiable(visibleEntries.toList()..sort(FmvEntrySort.compareByDate));
    return _sortedEntriesByDate!;
  }

  // known date by entry ID
  late Map<int?, int?> _savedDates;

  Future<void> loadDates() async {
    _savedDates = Map.unmodifiable(await localMediaDb.loadDates());
  }

  Set<CollectionFilter> _getAppHiddenFilters() => {
    ...settings.hiddenFilters,
    ...vaults.vaultDirectories.where(vaults.isLocked).map((v) => StoredAlbumFilter(v, null)),
  };

  Iterable<FmvEntry> _applyHiddenFilters(Iterable<FmvEntry> entries) {
    final hiddenFilters = {
      TrashFilter.instance,
      ..._getAppHiddenFilters(),
    };
    return entries.where((entry) => !hiddenFilters.any((filter) => filter.test(entry)));
  }

  Iterable<FmvEntry> _applyTrashFilter(Iterable<FmvEntry> entries) {
    final hiddenFilters = _getAppHiddenFilters();
    return entries.where(TrashFilter.instance.test).where((entry) => !hiddenFilters.any((filter) => filter.test(entry)));
  }

  void _invalidate({Set<FmvEntry>? entries, bool notify = true}) {
    invalidateEntries();
    invalidateAlbumFilterSummary(entries: entries, notify: notify);
    invalidateCountryFilterSummary(entries: entries, notify: notify);
    invalidatePlaceFilterSummary(entries: entries, notify: notify);
    invalidateStateFilterSummary(entries: entries, notify: notify);
    invalidateTagFilterSummary(entries: entries, notify: notify);
  }

  @override
  void invalidateEntries() {
    _visibleEntries = null;
    _trashedEntries = null;
    _sortedEntriesByDate = null;
  }

  void updateDerivedFilters([Set<FmvEntry>? entries]) {
    _invalidate(entries: entries);
    // it is possible for entries hidden by a filter type, to have an impact on other types
    // e.g. given a sole entry for country C and tag T, hiding T should make C disappear too
    updateDirectories();
    updateLocations();
    updateTags();
  }

  void _disposeEntries(bool Function(int id, FmvEntry entry) test) {
    final todoEntries = _entriesById.entries.where((kv) => test(kv.key, kv.value)).toSet();
    todoEntries.forEach((kv) => _entriesById.remove(kv.key)?.dispose());
  }

  void _disposeAllEntries() => _disposeEntries((_, _) => true);

  void addEntries(Set<FmvEntry> entries, {bool notify = true}) {
    if (entries.isEmpty) return;

    entries.where((entry) => entry.catalogDateMillis == null).forEach((entry) {
      entry.catalogDateMillis = _savedDates[entry.id];
    });

    final newEntriesById = Map.fromEntries(entries.map((entry) => MapEntry(entry.id, entry)));
    final newIds = newEntriesById.keys.toSet();
    _disposeEntries((id, _) => newIds.contains(id));

    _entriesById.addAll(newEntriesById);
    _invalidate(entries: entries, notify: notify);

    addDirectories(albums: _applyHiddenFilters(entries).map((entry) => entry.directory).toSet(), notify: notify);
    if (notify) {
      eventBus.fire(EntryAddedEvent(entries));
    }
  }

  Future<void> removeEntries(Set<String> uris, {required bool includeTrash}) async {
    if (uris.isEmpty) return;

    final oldEntries = allEntries.where((entry) => uris.contains(entry.uri)).toSet();
    if (!includeTrash) {
      oldEntries.removeWhere(TrashFilter.instance.test);
    }
    if (oldEntries.isEmpty) return;

    final oldIds = oldEntries.map((entry) => entry.id).toSet();
    await favourites.removeIds(oldIds);
    await covers.removeIds(oldIds);
    await localMediaDb.removeIds(oldIds);

    _disposeEntries((id, _) => oldIds.contains(id));
    updateDerivedFilters(oldEntries);
    eventBus.fire(EntryRemovedEvent(oldEntries));
  }

  void clearEntries() {
    _disposeAllEntries();
    _invalidate();

    // do not update directories/locations/tags here
    // as it could reset filter dependent settings (pins, bookmarks, etc.)
    // caller should take care of updating these at the right time
  }

  Future<void> _moveEntry(FmvEntry entry, Map newFields, {required bool persist}) async {
    newFields.keys.forEach((key) {
      final newValue = newFields[key];
      switch (key) {
        case EntryFields.contentId:
          entry.contentId = newValue as int?;
        case EntryFields.dateModifiedMillis:
          // `dateModifiedMillis` changes when moving entries to another directory,
          // but it does not change when renaming the containing directory
          entry.dateModifiedMillis = newValue as int?;
        case EntryFields.path:
          entry.path = newValue as String?;
        case EntryFields.title:
          entry.sourceTitle = newValue as String?;
        case EntryFields.trashed:
          final trashed = newValue as bool;
          entry.trashed = trashed;
          entry.trashDetails = trashed
              ? TrashDetails(
                  id: entry.id,
                  path: newFields[EntryFields.trashPath] as String,
                  dateMillis: DateTime.now().millisecondsSinceEpoch,
                )
              : null;
        case EntryFields.uri:
          entry.uri = newValue as String;
        case EntryFields.origin:
          entry.origin = newValue as int;
      }
    });
    if (entry.trashed) {
      final trashPath = entry.storagePath;
      if (trashPath != null) {
        entry.contentId = null;
        entry.uri = Uri.file(trashPath).toString();
      } else {
        debugPrint('failed to update uri from unknown trash path for uri=${entry.uri}');
      }
    }

    if (persist) {
      await covers.moveEntry(entry);
      final id = entry.id;
      await localMediaDb.updateEntry(id, entry);
      await localMediaDb.updateCatalogMetadata(id, entry.catalogMetadata);
      await localMediaDb.updateAddress(id, entry.addressDetails);
      await localMediaDb.updateTrash(id, entry.trashDetails);
    }
  }

  Future<void> renameStoredAlbum(String sourceAlbum, String destinationAlbum, Set<FmvEntry> entries, Set<MoveOpEvent> movedOps) async {
    final oldFilter = StoredAlbumFilter(sourceAlbum, null);
    final newFilter = StoredAlbumFilter(destinationAlbum, null);

    final group = albumGrouping.getFilterParent(oldFilter);
    final pinned = settings.pinnedFilters.contains(oldFilter);

    if (vaults.isVault(sourceAlbum)) {
      await vaults.rename(sourceAlbum, destinationAlbum);
    }

    final existingCover = covers.of(oldFilter);
    await covers.set(
      filter: newFilter,
      entryId: existingCover?.entryId,
      packageName: existingCover?.packageName,
      color: existingCover?.color,
    );

    renameNewAlbum(sourceAlbum, destinationAlbum);
    await updateAfterMove(
      todoEntries: entries,
      moveType: MoveType.move,
      destinationAlbums: {destinationAlbum},
      movedOps: movedOps,
    );

    // update bookmark
    final albumBookmarks = settings.drawerAlbumBookmarks;
    if (albumBookmarks != null) {
      final index = albumBookmarks.indexWhere((v) => v is StoredAlbumFilter && v.album == sourceAlbum);
      if (index >= 0) {
        albumBookmarks.removeAt(index);
        albumBookmarks.insert(index, newFilter);
        settings.drawerAlbumBookmarks = albumBookmarks;
      }
    }
    // update group
    if (group != null) {
      final newFilterUri = GroupingConversion.filterToUri(newFilter);
      if (newFilterUri != null) {
        albumGrouping.addToGroup({newFilterUri}, group);
      }
      final oldFilterUri = GroupingConversion.filterToUri(oldFilter);
      if (oldFilterUri != null) {
        albumGrouping.addToGroup({oldFilterUri}, null);
      }
    }
    // restore pin, as the obsolete album got removed and its associated state cleaned
    if (pinned) {
      settings.pinnedFilters = settings.pinnedFilters
        ..remove(oldFilter)
        ..add(newFilter);
    }
  }

  Future<void> updateAfterMove({
    required Set<FmvEntry> todoEntries,
    required MoveType moveType,
    required Set<String> destinationAlbums,
    required Set<MoveOpEvent> movedOps,
  }) async {
    if (movedOps.isEmpty) return;

    final replacedUris = movedOps
        .map((movedOp) => movedOp.newFields[EntryFields.path] as String?)
        .map((targetPath) {
          final existingEntry = allEntries.firstWhereOrNull((entry) => entry.path == targetPath && !entry.trashed);
          return existingEntry?.uri;
        })
        .nonNulls
        .toSet();
    await removeEntries(replacedUris, includeTrash: false);

    final fromAlbums = <String?>{};
    final movedEntries = <FmvEntry>{};
    final copy = moveType == MoveType.copy;
    if (copy) {
      movedOps.forEach((movedOp) {
        final sourceUri = movedOp.uri;
        final newFields = movedOp.newFields;
        final sourceEntry = todoEntries.firstWhereOrNull((entry) => entry.uri == sourceUri);
        if (sourceEntry != null) {
          fromAlbums.add(sourceEntry.directory);
          movedEntries.add(
            sourceEntry.copyWith(
              id: localMediaDb.nextId,
              uri: newFields[EntryFields.uri] as String?,
              path: newFields[EntryFields.path] as String?,
              contentId: newFields[EntryFields.contentId] as int?,
              // title can change when moved files are automatically renamed to avoid conflict
              sourceTitle: newFields[EntryFields.title] as String?,
              dateAddedSecs: newFields[EntryFields.dateAddedSecs] as int?,
              dateModifiedMillis: newFields[EntryFields.dateModifiedMillis] as int?,
              origin: newFields[EntryFields.origin] as int?,
            ),
          );
        } else {
          debugPrint('failed to find source entry with uri=$sourceUri');
        }
      });
      await localMediaDb.insertEntries(movedEntries);
      await localMediaDb.saveCatalogMetadata(movedEntries.map((entry) => entry.catalogMetadata).nonNulls.toSet());
      await localMediaDb.saveAddresses(movedEntries.map((entry) => entry.addressDetails).nonNulls.toSet());
    } else {
      await Future.forEach<MoveOpEvent>(movedOps, (movedOp) async {
        final newFields = movedOp.newFields;
        if (newFields.isNotEmpty) {
          final sourceUri = movedOp.uri;
          final entry = todoEntries.firstWhereOrNull((entry) => entry.uri == sourceUri);
          if (entry != null) {
            if (moveType == MoveType.fromBin) {
              newFields[EntryFields.trashed] = false;
            } else {
              fromAlbums.add(entry.directory);
            }
            movedEntries.add(entry);
            await _moveEntry(entry, newFields, persist: true);
          }
        }
      });
    }

    switch (moveType) {
      case .copy:
        addEntries(movedEntries);
      case .move:
      case .export:
        cleanEmptyAlbums(fromAlbums.nonNulls.toSet());
        addDirectories(albums: destinationAlbums);
      case .toBin:
      case .fromBin:
        updateDerivedFilters(movedEntries);
    }
    invalidateAlbumFilterSummary(directories: fromAlbums);
    _invalidate(entries: movedEntries);
    eventBus.fire(EntryMovedEvent(moveType, movedEntries));
  }

  Future<void> updateAfterRename({
    required Set<FmvEntry> todoEntries,
    required Set<MoveOpEvent> movedOps,
    required bool persist,
  }) async {
    if (movedOps.isEmpty) return;

    final movedEntries = <FmvEntry>{};
    await Future.forEach<MoveOpEvent>(movedOps, (movedOp) async {
      final newFields = movedOp.newFields;
      if (newFields.isNotEmpty) {
        final sourceUri = movedOp.uri;
        final entry = todoEntries.firstWhereOrNull((entry) => entry.uri == sourceUri);
        if (entry != null) {
          movedEntries.add(entry);
          await _moveEntry(entry, newFields, persist: persist);
        }
      }
    });

    eventBus.fire(EntryMovedEvent(MoveType.move, movedEntries));
  }

  SourceScope get loadedScope;

  SourceScope get targetScope;

  Future<void> init({
    required SourceScope scope,
    AnalysisController? analysisController,
    bool loadTopEntriesFirst = false,
  });

  Future<Set<String>> refreshUris(Set<String> changedUris, {AnalysisController? analysisController});

  Future<void> refreshEntries(Set<FmvEntry> entries, Set<EntryDataType> dataTypes) async {
    const background = false;
    const persist = true;

    await Future.forEach(entries, (entry) async {
      await entry.refresh(background: background, persist: persist, dataTypes: dataTypes);
    });

    if (dataTypes.contains(EntryDataType.aspectRatio)) {
      onAspectRatioChanged();
    }

    if (dataTypes.contains(EntryDataType.catalog)) {
      // explicit GC before cataloguing multiple items
      await deviceService.requestGarbageCollection();
      await Future.forEach(entries, (entry) async {
        await entry.catalog(background: background, force: true, persist: persist);
        await localMediaDb.updateCatalogMetadata(entry.id, entry.catalogMetadata);
      });
      onCatalogMetadataChanged();
    }

    if (dataTypes.contains(EntryDataType.address)) {
      await Future.forEach(entries, (entry) async {
        await entry.locate(background: background, force: true, geocoderLocale: settings.fmvLocale);
        await localMediaDb.updateAddress(entry.id, entry.addressDetails);
      });
      onAddressMetadataChanged();
    }

    updateDerivedFilters(entries);
    eventBus.fire(EntryRefreshedEvent(entries));
  }

  Future<void> analyze(AnalysisController? analysisController, {Set<FmvEntry>? entries}) async {
    // not only visible entries, as hidden and vault items may be analyzed
    final todoEntries = entries ?? allEntries;
    final defaultAnalysisController = AnalysisController();
    final _analysisController = analysisController ?? defaultAnalysisController;
    final force = _analysisController.force;
    if (!_analysisController.isStopping) {
      var startAnalysisService = false;
      if (_analysisController.canStartService && settings.canUseAnalysisService) {
        // cataloguing
        if (!startAnalysisService) {
          final opCount = (force ? todoEntries : todoEntries.where(TagMixin.catalogEntriesTest)).length;
          startAnalysisService = opCount > TagMixin.commitCountThreshold;
        }
        // ignore locating countries
        // locating places
        if (!startAnalysisService && await availability.canLocatePlaces) {
          final opCount = (force ? todoEntries.where((entry) => entry.hasGps) : todoEntries.where(LocationMixin.locatePlacesTest)).length;
          startAnalysisService = opCount > LocationMixin.commitCountThreshold;
        }
      }

      debugPrint('analyze ${todoEntries.length} entries, force=$force, starting service=$startAnalysisService');
      if (startAnalysisService) {
        final lifecycleState = FmvApp.lifecycleStateNotifier.value;
        switch (lifecycleState) {
          case .resumed:
          case .inactive:
            await AnalysisService.startService(
              force: force,
              entryIds: entries?.map((entry) => entry.id).toList(),
            );
          default:
            unawaited(reportService.log('analysis service not started because app is in state=$lifecycleState'));
        }
      } else {
        // explicit GC before cataloguing multiple items
        await deviceService.requestGarbageCollection();
        await catalogEntries(_analysisController, todoEntries);
        updateDerivedFilters(todoEntries);
        await locateEntries(_analysisController, todoEntries);
        updateDerivedFilters(todoEntries);
      }
    }
    defaultAnalysisController.dispose();
    state = SourceState.ready;
  }

  void onAspectRatioChanged() => eventBus.fire(AspectRatioChangedEvent());

  // monitoring

  bool _canRefresh = true;

  void pauseMonitoring() => _canRefresh = false;

  void resumeMonitoring() => _canRefresh = true;

  bool get canRefresh => _canRefresh;

  // filter summary

  int count(CollectionFilter filter) {
    switch (filter) {
      case AlbumBaseFilter _:
        return albumEntryCount(filter);
      case LocationFilter(level: LocationLevel.country):
        return countryEntryCount(filter);
      case LocationFilter(level: LocationLevel.state):
        return stateEntryCount(filter);
      case LocationFilter(level: LocationLevel.place):
        return placeEntryCount(filter);
      case TagBaseFilter _:
        return tagEntryCount(filter);
    }
    return 0;
  }

  int size(CollectionFilter filter) {
    switch (filter) {
      case AlbumBaseFilter _:
        return albumSize(filter);
      case LocationFilter(level: LocationLevel.country):
        return countrySize(filter);
      case LocationFilter(level: LocationLevel.state):
        return stateSize(filter);
      case LocationFilter(level: LocationLevel.place):
        return placeSize(filter);
      case TagBaseFilter _:
        return tagSize(filter);
    }
    return 0;
  }

  FmvEntry? recentEntry(CollectionFilter filter) {
    switch (filter) {
      case AlbumBaseFilter _:
        return albumRecentEntry(filter);
      case LocationFilter(level: LocationLevel.country):
        return countryRecentEntry(filter);
      case LocationFilter(level: LocationLevel.state):
        return stateRecentEntry(filter);
      case LocationFilter(level: LocationLevel.place):
        return placeRecentEntry(filter);
      case TagBaseFilter _:
        return tagRecentEntry(filter);
    }
    return null;
  }

  FmvEntry? coverEntry(CollectionFilter filter) {
    final id = covers.of(filter)?.entryId;
    if (id != null) {
      final entry = visibleEntries.firstWhereOrNull((entry) => entry.id == id);
      if (entry != null) return entry;
    }
    return recentEntry(filter);
  }

  void _onFilterVisibilityChanged(Set<CollectionFilter> newlyVisibleFilters) {
    updateDerivedFilters();
    eventBus.fire(const FilterVisibilityChangedEvent());

    if (newlyVisibleFilters.isNotEmpty) {
      final candidateEntries = visibleEntries.where((entry) => newlyVisibleFilters.any((f) => f.test(entry))).toSet();
      analyze(null, entries: candidateEntries);
    }
  }

  void _onVaultsChanged() {
    final newlyVisibleFilters = vaults.vaultDirectories.whereNot(vaults.isLocked).map((v) => StoredAlbumFilter(v, null)).toSet();
    _onFilterVisibilityChanged(newlyVisibleFilters);
  }
}

class AspectRatioChangedEvent {}

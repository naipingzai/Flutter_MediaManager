import 'dart:async';

import 'package:flutter_media_view/app_mode.dart';
import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_location.dart';
import 'package:flutter_media_view/function/filters/coordinate.dart';
import 'package:flutter_media_view/function/filters/covered_location.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/function_highlight.dart';
import 'package:flutter_media_view/function/media/media_geotiff.dart';
import 'package:flutter_media_view/function/settings/enums_accessibility_animations.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/function/source/tag.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/view.dart';
import 'package:flutter_media_view/ui/collection/widgets_collection_collection_page.dart';
import 'package:flutter_media_view/ui/collection/widgets_collection_entry_set_action_delegate.dart';
import 'package:flutter_media_view/ui/common/common_basic_font_size_icon_theme.dart';
import 'package:flutter_media_view/ui/common/common_basic_insets.dart';
import 'package:flutter_media_view/ui/common/common_basic_popup_menu_row.dart';
import 'package:flutter_media_view/ui/common/common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/common/common_behaviour_routes.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/common_identity_buttons_captioned_button.dart';
import 'package:flutter_media_view/ui/common/common_map_geo_map.dart';
import 'package:flutter_media_view/ui/common/common_map_map_action_delegate.dart';
import 'package:flutter_media_view/ui/common/common_providers_highlight_info_provider.dart';
import 'package:flutter_media_view/ui/common/common_providers_map_theme_provider.dart';
import 'package:flutter_media_view/ui/common/dialogs_fmv_dialog.dart';
import 'package:flutter_media_view/ui/common/map_scroller.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_controls_notifications.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_entry_viewer_page.dart';
import 'package:fmv_map/flutter_media_view_map.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class MapPage extends StatelessWidget {
  static const routeName = '/map';

  final CollectionLens collection;
  final LatLng? initialLocation;
  final double? initialZoom;
  final FmvEntry? initialEntry;
  final MappedGeoTiff? overlayEntry;
  final List<GeoTrack>? tracks;

  const MapPage({
    super.key,
    required this.collection,
    this.initialLocation,
    this.initialZoom,
    this.initialEntry,
    this.overlayEntry,
    this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // do not rely on the `HighlightInfoProvider` app level
        // as the map can be stacked on top of other pages
        // that catch highlight events and will not let it bubble up
        HighlightInfoProvider(),
        // opening collection can be used by map actions
        ChangeNotifierProvider<CollectionLens>.value(value: collection),
      ],
      child: FmvScaffold(
        body: SafeArea(
          left: false,
          top: false,
          right: false,
          bottom: true,
          child: _Content(
            collection: collection,
            initialLocation: initialLocation,
            initialZoom: initialZoom,
            initialEntry: initialEntry,
            overlayEntry: overlayEntry,
            tracks: tracks,
          ),
        ),
      ),
    );
  }
}

class _Content extends StatefulWidget {
  final CollectionLens collection;
  final LatLng? initialLocation;
  final double? initialZoom;
  final FmvEntry? initialEntry;
  final MappedGeoTiff? overlayEntry;
  final List<GeoTrack>? tracks;

  const _Content({
    required this.collection,
    this.initialLocation,
    this.initialZoom,
    this.initialEntry,
    this.overlayEntry,
    this.tracks,
  });

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> with SingleTickerProviderStateMixin {
  final Set<StreamSubscription> _subscriptions = {};
  final FmvMapController _mapController = FmvMapController();
  final ValueNotifier<bool> _isPageAnimatingNotifier = ValueNotifier(false);
  final ValueNotifier<int?> _selectedIndexNotifier = ValueNotifier(0);
  final ValueNotifier<CollectionLens?> _regionCollectionNotifier = ValueNotifier(null);
  final ValueNotifier<LatLng?> _dotLocationNotifier = ValueNotifier(null);
  final ValueNotifier<FmvEntry?> _dotEntryNotifier = ValueNotifier(null);
  final ValueNotifier<double> _overlayOpacityNotifier = ValueNotifier(1);
  final ValueNotifier<bool> _overlayVisible = ValueNotifier(true);
  late AnimationController _overlayAnimationController;
  late CurvedAnimation _overlayScale, _scrollerSize;
  CoordinateFilter? _regionFilter;

  CollectionLens? get regionCollection => _regionCollectionNotifier.value;

  CollectionLens get openingCollection => widget.collection;

  @override
  void initState() {
    super.initState();

    if (settings.mapStyle?.isHeavy ?? false) {
      _isPageAnimatingNotifier.value = true;
      Future.delayed(ADurations.pageTransitionLoose * timeDilation).then((_) {
        if (!mounted) return;
        _isPageAnimatingNotifier.value = false;
      });
    }

    _overlayAnimationController = AnimationController(
      duration: context.read<DurationsData>().viewerOverlayAnimation,
      vsync: this,
    );
    _overlayScale = CurvedAnimation(
      parent: _overlayAnimationController,
      curve: Curves.easeOutBack,
    );
    _scrollerSize = CurvedAnimation(
      parent: _overlayAnimationController,
      curve: Curves.easeOutQuad,
    );
    _overlayVisible.addListener(_onOverlayVisibleChanged);

    _subscriptions.add(_mapController.idleUpdates.listen((event) => _onIdle(event.bounds)));
    _subscriptions.add(openingCollection.source.eventBus.on<CatalogMetadataChangedEvent>().listen((e) => _updateRegionCollection()));

    _selectedIndexNotifier.addListener(_onThumbnailIndexChanged);
    Future.delayed(ADurations.pageTransitionLoose * timeDilation + const Duration(seconds: 1), () {
      if (!mounted) return;
      final regionEntries = regionCollection?.sortedEntries ?? [];
      final initialEntry = widget.initialEntry ?? regionEntries.firstOrNull;
      if (initialEntry != null) {
        final index = regionEntries.indexOf(initialEntry);
        if (index != -1) {
          _selectedIndexNotifier.value = index;
        }
        _onEntrySelected(initialEntry);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _onOverlayVisibleChanged(animate: false));
  }

  @override
  void dispose() {
    _subscriptions
      ..forEach((sub) => sub.cancel())
      ..clear();
    _mapController.dispose();
    _isPageAnimatingNotifier.dispose();
    _selectedIndexNotifier.dispose();
    _regionCollectionNotifier.value?.dispose();
    _regionCollectionNotifier.dispose();
    _dotLocationNotifier.dispose();
    _dotEntryNotifier.value?.metadataChangeNotifier.removeListener(_onMarkerEntryMetadataChanged);
    _dotEntryNotifier.dispose();
    _overlayOpacityNotifier.dispose();
    _overlayVisible.dispose();
    _overlayScale.dispose();
    _scrollerSize.dispose();
    _overlayAnimationController.dispose();

    // provided collection should be a new instance specifically created
    // for the `MapPage` widget, so it can be safely disposed here
    widget.collection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener(
      onNotification: (notification) {
        if (notification is SelectFilterNotification) {
          _goToCollection(notification.filter);
        } else if (notification is OpenMapAppNotification) {
          _openMapApp();
        } else {
          return false;
        }
        return true;
      },
      child: Selector<Settings, EntryMapStyle?>(
        selector: (context, s) => s.mapStyle,
        builder: (context, mapStyle, child) {
          late Widget scroller;
          if (mapStyle?.isHeavy ?? false) {
            // the map widget is too heavy for a smooth resizing animation
            // so we just toggle visibility when overlay animation is done
            scroller = ValueListenableBuilder<double>(
              valueListenable: _overlayAnimationController,
              builder: (context, animation, child) {
                return Visibility(
                  visible: !_overlayAnimationController.isDismissed,
                  child: child!,
                );
              },
              child: child,
            );
          } else {
            // the map widget is light enough for a smooth resizing animation
            scroller = FadeTransition(
              opacity: _scrollerSize,
              child: SizeTransition(
                axis: Axis.vertical,
                sizeFactor: _scrollerSize,
                alignment: const Alignment(-1, 1),
                child: child,
              ),
            );
          }

          return Column(
            children: [
              Expanded(child: _buildMap()),
              scroller,
            ],
          );
        },
        child: Column(
          mainAxisSize: .min,
          children: [
            const SizedBox(height: 8),
            const Divider(height: 0),
            _buildOverlayControls(),
            MapEntryScroller(
              regionCollectionNotifier: _regionCollectionNotifier,
              dotEntryNotifier: _dotEntryNotifier,
              selectedIndexNotifier: _selectedIndexNotifier,
              onTap: (index) => _goToViewer(_getRegionEntry(index)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final appMode = context.watch<ValueNotifier<AppMode>>().value;
    final canPop = Navigator.maybeOf(context)?.canPop() == true;
    Widget child = MapTheme(
      interactive: true,
      showCoordinateFilter: true,
      navigationButton: canPop ? MapNavigationButton.back : MapNavigationButton.close,
      scale: _overlayScale,
      attributionPadding: const EdgeInsets.symmetric(horizontal: 8),
      child: GeoMap(
        // key is expected by test driver
        key: const Key('map_view'),
        controller: _mapController,
        collection: openingCollection,
        availableSize: MediaQuery.sizeOf(context),
        initialCenter: widget.initialLocation ?? widget.initialEntry?.latLng ?? widget.overlayEntry?.center,
        initialZoom: widget.initialZoom,
        isAnimatingNotifier: _isPageAnimatingNotifier,
        dotLocationNotifier: _dotLocationNotifier,
        overlayOpacityNotifier: _overlayOpacityNotifier,
        overlayEntry: widget.overlayEntry,
        tracks: widget.tracks,
        onMapTap: (_) => _toggleOverlay(),
        onMarkerTap: (location, entry) async {
          final index = regionCollection?.sortedEntries.indexOf(entry);
          if (index != null && _selectedIndexNotifier.value != index) {
            _selectedIndexNotifier.value = index;
          }
          await Future.delayed(const Duration(milliseconds: 500));
          context.read<HighlightInfo>().set(entry);
        },
        onMarkerLongPress: appMode.canEditEntry ? _onMarkerLongPress : null,
      ),
    );
    if (settings.useTvLayout) {
      child = DirectionalSafeArea(
        top: false,
        end: false,
        bottom: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: .min,
              children:
                  [
                        MapAction.selectStyle,
                        MapAction.zoomIn,
                        MapAction.zoomOut,
                      ]
                      .mapIndexed(
                        (i, action) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: CaptionedButton(
                            icon: action.getIcon(),
                            caption: action.getText(context),
                            autofocus: i == 0,
                            onPressed: () => MapActionDelegate(_mapController).onActionSelected(context, action),
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(width: 16),
            Expanded(child: child),
          ],
        ),
      );
    }
    return child;
  }

  Widget _buildOverlayControls() {
    if (widget.overlayEntry == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ValueListenableBuilder<double>(
        valueListenable: _overlayOpacityNotifier,
        builder: (context, overlayOpacity, child) {
          return Row(
            children: [
              const Icon(AIcons.opacity),
              Expanded(
                child: Slider(
                  value: _overlayOpacityNotifier.value,
                  onChanged: (v) => _overlayOpacityNotifier.value = v,
                  min: 0,
                  max: 1,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onIdle(ZoomedBounds bounds) {
    _regionFilter = CoordinateFilter(bounds.sw, bounds.ne);
    _updateRegionCollection();
  }

  void _updateRegionCollection() {
    final regionFilter = _regionFilter;
    if (regionFilter == null) return;

    FmvEntry? selectedEntry;
    if (regionCollection != null) {
      final regionEntries = regionCollection!.sortedEntries;
      final selectedIndex = _selectedIndexNotifier.value;
      selectedEntry = selectedIndex != null && 0 <= selectedIndex && selectedIndex < regionEntries.length ? regionEntries[selectedIndex] : null;
    }

    final oldRegionCollection = regionCollection;
    final newRegionCollection = openingCollection.copyWith(
      filters: {
        ...openingCollection.filters.whereNot((v) => v is CoordinateFilter),
        regionFilter,
      },
    );
    _regionCollectionNotifier.value = newRegionCollection;
    oldRegionCollection?.dispose();

    // get entries from the new collection, so the entry order is the same
    // as the one used by the thumbnail scroller (considering sort/section/group)
    final regionEntries = regionCollection!.sortedEntries;
    final selectedIndex = (selectedEntry != null && regionEntries.contains(selectedEntry))
        ? regionEntries.indexOf(selectedEntry)
        : regionEntries.isEmpty
        ? null
        : 0;
    _selectedIndexNotifier.value = selectedIndex;
    // force update, as the region entries may change without a change of index
    _onThumbnailIndexChanged();
  }

  FmvEntry? _getRegionEntry(int? index) {
    if (index != null && index >= 0 && regionCollection != null) {
      final regionEntries = regionCollection!.sortedEntries;
      if (index < regionEntries.length) {
        return regionEntries[index];
      }
    }
    return null;
  }

  void _onThumbnailIndexChanged() => _onEntrySelected(_getRegionEntry(_selectedIndexNotifier.value));

  void _onEntrySelected(FmvEntry? selectedEntry) {
    _dotEntryNotifier.value?.metadataChangeNotifier.removeListener(_onMarkerEntryMetadataChanged);
    _dotEntryNotifier.value = selectedEntry;
    selectedEntry?.metadataChangeNotifier.addListener(_onMarkerEntryMetadataChanged);
    _onMarkerEntryMetadataChanged();
  }

  void _onMarkerEntryMetadataChanged() {
    _dotLocationNotifier.value = _dotEntryNotifier.value?.latLng;
  }

  void _goToViewer(FmvEntry? initialEntry) {
    if (initialEntry == null) return;

    // derive a stable collection out of the route builder,
    // as the region collection may change on rebuild,
    // when the map view size updates on device rotation
    final viewerCollection = regionCollection?.copyWith(
      listenToSource: false,
    );
    final appModeNotifier = context.read<ValueNotifier<AppMode>>();
    Navigator.maybeOf(context)?.push(
      TransparentMaterialPageRoute(
        settings: const RouteSettings(name: EntryViewerPage.routeName),
        pageBuilder: (context, a, sa) {
          // propagate app mode from the map page, as it could be locally overridden
          // and differ from the real app mode above the `Navigator`
          return ListenableProvider<ValueNotifier<AppMode>>.value(
            value: appModeNotifier,
            child: EntryViewerPage(
              collection: viewerCollection,
              initialEntry: initialEntry,
            ),
          );
        },
      ),
    );
  }

  void _goToCollection(CollectionFilter filter) {
    final isMainMode = context.read<ValueNotifier<AppMode>>().value == .main;
    if (!isMainMode) return;

    Navigator.maybeOf(context)?.pushAndRemoveUntil(
      MaterialPageRoute(
        settings: const RouteSettings(name: CollectionPage.routeName),
        builder: (context) {
          final filters = {...openingCollection.filters, filter};
          if (filter is CoordinateFilter) {
            filters.removeWhere((v) => (v is CoordinateFilter && v != filter) || v == LocationFilter.located);
          }
          return CollectionPage(
            source: openingCollection.source,
            filters: filters,
          );
        },
      ),
      (route) => false,
    );
  }

  Future<void> _openMapApp() async {
    final latLng = _dotEntryNotifier.value?.latLng ?? _mapController.idleBounds?.projectedCenter;
    if (latLng != null) {
      await appService.openMap(latLng).then((success) {
        if (!success) showNoMatchingAppDialog(context);
      });
    }
  }

  // overlay

  void _toggleOverlay() => _overlayVisible.value = !_overlayVisible.value;

  Future<void> _onOverlayVisibleChanged({bool animate = true}) async {
    if (_overlayVisible.value) {
      if (animate) {
        await _overlayAnimationController.forward();
      } else {
        _overlayAnimationController.value = _overlayAnimationController.upperBound;
      }
    } else {
      if (animate) {
        await _overlayAnimationController.reverse();
      } else {
        _overlayAnimationController.reset();
      }
    }
  }

  // cluster context menu

  Future<void> _onMarkerLongPress(
    LatLng markerLocation,
    FmvEntry markerEntry,
    Set<FmvEntry> clusterEntries,
    Offset tapLocalPosition,
    WidgetBuilder markerBuilder,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    const touchArea = Size(kMinInteractiveDimension, kMinInteractiveDimension);
    final animations = context.read<Settings>().accessibilityAnimations;
    final selectedAction = await showMenu<MapClusterAction>(
      context: context,
      position: RelativeRect.fromRect(tapLocalPosition & touchArea, Offset.zero & overlay.size),
      items: [
        PopupMenuItem(
          child: Row(
            mainAxisSize: .min,
            children: [
              markerBuilder(context),
              const SizedBox(width: 16),
              Text(context.l10n.itemCount(clusterEntries.length)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ...[
          MapClusterAction.editLocation,
          MapClusterAction.removeLocation,
        ].map(_buildMenuItem),
      ],
      popUpAnimationStyle: animations.popUpAnimationStyle,
    );
    if (selectedAction != null) {
      // wait for the popup menu to hide before proceeding with the action
      await Future.delayed(animations.popUpAnimationDelay * timeDilation);
      final delegate = EntrySetActionDelegate();
      switch (selectedAction) {
        case .editLocation:
          final regionEntries = regionCollection?.sortedEntries ?? [];
          final markerIndex = regionEntries.indexOf(markerEntry);
          final location = await delegate.editLocationByMap(context, clusterEntries, markerLocation, openingCollection.copyWith());
          if (location != null) {
            if (markerIndex != -1) {
              _selectedIndexNotifier.value = markerIndex;
            }
            _mapController.moveTo(location);
          }
        case .removeLocation:
          await delegate.removeLocation(context, clusterEntries);
      }
    }
  }

  PopupMenuItem<MapClusterAction> _buildMenuItem(MapClusterAction action) {
    return PopupMenuItem(
      value: action,
      child: FontSizeIconTheme(
        child: MenuRow(
          text: action.getText(context),
          icon: action.getIcon(),
        ),
      ),
    );
  }
}

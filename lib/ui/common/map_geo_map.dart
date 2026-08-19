import 'dart:async';
import 'dart:math';

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_images.dart';
import 'package:flutter_media_view/function/entry/extensions_location.dart';
import 'package:flutter_media_view/function/entry/sort.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/function/geo/function_poi.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/identity/identity_buttons_overlay_button.dart';
import 'package:flutter_media_view/ui/common/map_attribution.dart';
import 'package:flutter_media_view/ui/common/map_buttons_panel.dart';
import 'package:flutter_media_view/ui/common/map_decorator.dart';
import 'package:flutter_media_view/ui/common/leaflet_map.dart';
import 'package:flutter_media_view/ui/common/map_action_delegate.dart';
import 'package:flutter_media_view/ui/common/thumbnails/thumbnails_image.dart';
import 'package:fmv_map/flutter_media_view_map.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:fmv_utils/flutter_media_view_utils.dart';
import 'package:collection/collection.dart';
import 'package:fluster/fluster.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class GeoMap extends StatefulWidget {
  final FmvMapController controller;
  final CollectionLens? collection;
  final List<FmvEntry>? entries;
  final Size availableSize;
  final LatLng? initialCenter;
  final double? initialZoom;
  final ValueNotifier<bool> isAnimatingNotifier;
  final ValueNotifier<LatLng?>? dotLocationNotifier;
  final ValueNotifier<double>? overlayOpacityNotifier;
  final MapOverlay? overlayEntry;
  final List<GeoTrack>? tracks;
  final UserZoomChangeCallback? onUserZoomChange;
  final MapTapCallback? onMapTap;
  final void Function(
    LatLng markerLocation,
    FmvEntry markerEntry,
  )?
  onMarkerTap;
  final void Function(
    LatLng markerLocation,
    FmvEntry markerEntry,
    Set<FmvEntry> clusterEntries,
    Offset tapLocalPosition,
    WidgetBuilder markerBuilder,
  )?
  onMarkerLongPress;
  final void Function(BuildContext context)? openMapPage;

  const GeoMap({
    super.key,
    required this.controller,
    this.collection,
    this.entries,
    required this.availableSize,
    this.initialCenter,
    this.initialZoom,
    required this.isAnimatingNotifier,
    this.dotLocationNotifier,
    this.overlayOpacityNotifier,
    this.overlayEntry,
    this.tracks,
    this.onUserZoomChange,
    this.onMapTap,
    this.onMarkerTap,
    this.onMarkerLongPress,
    this.openMapPage,
  }) : assert(collection != null || entries != null);

  @override
  State<GeoMap> createState() => _GeoMapState();
}

class _GeoMapState extends State<GeoMap> {
  final Set<StreamSubscription> _subscriptions = {};

  // as of google_maps_flutter v2.0.6, Google map initialization is blocking
  // cf https://github.com/flutter/flutter/issues/28493
  // it is especially severe the first time, but still significant afterwards
  // so we prevent loading it while scrolling or animating
  bool _heavyMapLoaded = false;
  late final ValueNotifier<ZoomedBounds> _boundsNotifier;
  Fluster<GeoEntry<FmvEntry>>? _defaultMarkerCluster;
  Fluster<GeoEntry<FmvEntry>>? _slowMarkerCluster;
  final AChangeNotifier _clusterChangeNotifier = .new();

  final ValueNotifier<List<GeoTrack>> _tracksNotifier = ValueNotifier([]);

  List<FmvEntry> get entries => widget.collection?.sortedEntries ?? widget.entries ?? [];

  // cap initial zoom to avoid a zoom change
  // when toggling overlay on Google map initial state
  static const double minInitialZoom = 3;

  static const maxTrackPointInterval = Duration(days: 2);
  static const minTrackPointCount = 2;

  @override
  void initState() {
    super.initState();
    _boundsNotifier = ValueNotifier(_initBounds());
    _registerWidget(widget);
    _onCollectionChanged();
  }

  @override
  void didUpdateWidget(covariant GeoMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
  }

  @override
  void dispose() {
    _boundsNotifier.dispose();
    _clusterChangeNotifier.dispose();
    _unregisterWidget(widget);
    super.dispose();
  }

  void _registerWidget(GeoMap widget) {
    widget.collection?.addListener(_onCollectionChanged);
    _subscriptions.add(widget.controller.markerLocationChanges.listen((event) => _onCollectionChanged()));
    // not specific to widget, but here to be next to other subscriptions
    _subscriptions.add(settings.updateStream.where((event) => event.key == SettingKeys.mapShowItemTracksKey).listen((_) => _updateItemTracks()));
  }

  void _unregisterWidget(GeoMap widget) {
    widget.collection?.removeListener(_onCollectionChanged);
    _subscriptions
      ..forEach((sub) => sub.cancel())
      ..clear();
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    void onMarkerLongPress(GeoEntry<FmvEntry> geoEntry, LatLng tapLocation) => _onMarkerLongPress(
      geoEntry: geoEntry,
      tapLocation: tapLocation,
      devicePixelRatio: devicePixelRatio,
    );

    return Selector<Settings, EntryMapStyle?>(
      selector: (context, s) => s.mapStyle,
      builder: (context, mapStyle, child) {
        final isHeavy = mapStyle?.isHeavy ?? false;
        final countFormatter = settings.fmvLocale.decimalNumberFormat().format;
        Widget _buildMarkerWidget(MarkerKey<FmvEntry> key) => ImageMarker(
          key: key,
          count: key.count,
          countFormatter: countFormatter,
          buildThumbnailImage: (extent) => ThumbnailImage(
            entry: key.entry,
            extent: extent,
            devicePixelRatio: devicePixelRatio,
            progressive: !isHeavy,
          ),
        );
        bool _isMarkerImageReady(MarkerKey<FmvEntry> key) => key.entry.isThumbnailReady(extent: MapThemeData.markerImageExtent);

        Widget child = const SizedBox();
        if (mapStyle != null) {
          if (mapStyle.needMobileService) {
            child = mobileServices.buildMap<FmvEntry>(
              controller: widget.controller,
              clusterListenable: _clusterChangeNotifier,
              boundsNotifier: _boundsNotifier,
              style: mapStyle,
              decoratorBuilder: _decorateMap,
              buttonPanelBuilder: _buildButtonPanel,
              markerClusterBuilder: _buildMarkerClusters,
              markerWidgetBuilder: _buildMarkerWidget,
              markerImageReadyChecker: _isMarkerImageReady,
              dotLocationNotifier: widget.dotLocationNotifier,
              tracksNotifier: _tracksNotifier,
              overlayOpacityNotifier: widget.overlayOpacityNotifier,
              overlayEntry: widget.overlayEntry,
              onUserZoomChange: widget.onUserZoomChange,
              onMapTap: widget.onMapTap,
              onMarkerTap: _onMarkerTap,
              onMarkerLongPress: onMarkerLongPress,
            );
          } else {
            child = EntryLeafletMap<FmvEntry>(
              controller: widget.controller,
              clusterListenable: _clusterChangeNotifier,
              boundsNotifier: _boundsNotifier,
              style: mapStyle,
              decoratorBuilder: _decorateMap,
              buttonPanelBuilder: _buildButtonPanel,
              markerClusterBuilder: _buildMarkerClusters,
              markerWidgetBuilder: _buildMarkerWidget,
              dotLocationNotifier: widget.dotLocationNotifier,
              tracksNotifier: _tracksNotifier,
              markerSize: Size(
                MapThemeData.markerImageExtent + MapThemeData.markerOuterBorderWidth * 2,
                MapThemeData.markerImageExtent + MapThemeData.markerOuterBorderWidth * 2 + MapThemeData.markerArrowSize.height,
              ),
              dotMarkerSize: const Size(
                MapThemeData.markerDotDiameter + MapThemeData.markerOuterBorderWidth * 2,
                MapThemeData.markerDotDiameter + MapThemeData.markerOuterBorderWidth * 2,
              ),
              overlayOpacityNotifier: widget.overlayOpacityNotifier,
              overlayEntry: widget.overlayEntry,
              onUserZoomChange: widget.onUserZoomChange,
              onMapTap: widget.onMapTap,
              onMarkerTap: _onMarkerTap,
              onMarkerLongPress: onMarkerLongPress,
            );
          }
        } else {
          final overlay = Center(
            child: OverlayTextButton(
              onPressed: () => MapActionDelegate.selectStyle(context),
              child: Row(
                mainAxisSize: .min,
                children: [
                  const Icon(AIcons.layers),
                  const SizedBox(width: 8),
                  Text(context.l10n.mapStyleTooltip),
                ],
              ),
            ),
          );
          child = _decorateMap(context, overlay);
        }

        final mapHeight = context.select<MapThemeData, double?>((v) => v.mapHeight);
        child = Column(
          crossAxisAlignment: .start,
          children: [
            BackdropGroup(
              child: mapHeight != null
                  ? SizedBox(
                      height: mapHeight,
                      child: child,
                    )
                  : Expanded(child: child),
            ),
            SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: context.select<MapThemeData, EdgeInsets>((v) => v.attributionPadding),
                child: Attribution(style: mapStyle),
              ),
            ),
          ],
        );

        return AnimatedSize(
          alignment: Alignment.topCenter,
          curve: Curves.easeInOutCubic,
          duration: ADurations.mapStyleSwitchAnimation,
          child: ValueListenableBuilder<bool>(
            valueListenable: widget.isAnimatingNotifier,
            builder: (context, animating, child) {
              if (!animating && isHeavy) {
                _heavyMapLoaded = true;
              }
              Widget replacement = Stack(
                children: [
                  const MapDecorator(
                    child: SizedBox(),
                  ),
                  _buildButtonPanel(context),
                ],
              );
              if (mapHeight != null) {
                replacement = SizedBox(
                  height: mapHeight,
                  child: replacement,
                );
              }
              return Visibility(
                visible: !isHeavy || _heavyMapLoaded,
                replacement: replacement,
                child: child!,
              );
            },
            child: child,
          ),
        );
      },
    );
  }

  ZoomedBounds _initBounds() {
    ZoomedBounds? bounds;

    final overlayEntry = widget.overlayEntry;
    if (overlayEntry != null) {
      // fit map to overlaid item
      final corner1 = overlayEntry.topLeft;
      final corner2 = overlayEntry.bottomRight;
      if (corner1 != null && corner2 != null) {
        bounds = ZoomedBounds.fromPoints(
          points: {corner1, corner2},
        );
      }
    }

    final initialZoom = widget.initialZoom ?? settings.infoMapZoom;
    if (bounds == null) {
      LatLng? centerToSave;
      final initialCenter = widget.initialCenter;
      if (initialCenter != null) {
        // fit map for specified center and user zoom
        bounds = ZoomedBounds.fromPoints(
          points: {initialCenter},
          collocationZoom: initialZoom,
        );
        centerToSave = initialCenter;
      } else {
        // fit map for all located items if possible, falling back to most recent items
        bounds = _initBoundsForEntries(entries: entries);
        centerToSave = bounds?.projectedCenter;
      }

      if (centerToSave != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          settings.mapDefaultCenter = centerToSave;
        });
      }
    }
    if (bounds == null) {
      // fallback to default center
      var center = settings.mapDefaultCenter;
      if (center == null) {
        center = PointsOfInterest.wonders[Random().nextInt(PointsOfInterest.wonders.length)];
        WidgetsBinding.instance.addPostFrameCallback((_) => settings.mapDefaultCenter = center);
      }
      bounds = ZoomedBounds.fromPoints(
        points: {center},
        collocationZoom: initialZoom,
      );
    }

    return bounds.copyWith(
      zoom: max(bounds.zoom, minInitialZoom),
    );
  }

  ZoomedBounds? _initBoundsForEntries({required List<FmvEntry> entries, int? recentCount}) {
    if (recentCount != null) {
      entries = List.of(entries)..sort(FmvEntrySort.compareByDate);
      entries = entries.take(recentCount).toList();
    }

    if (entries.isEmpty) return null;

    final points = entries.map((v) => v.latLng!).toSet();
    var bounds = ZoomedBounds.fromPoints(
      points: points,
      collocationZoom: settings.infoMapZoom,
    );
    bounds = bounds.copyWith(zoom: max(minInitialZoom, bounds.zoom.floorToDouble()));

    final neededSize = bounds.toDisplaySize();
    final availableSize = widget.availableSize;
    if (neededSize.width > availableSize.width || neededSize.height > availableSize.height) {
      return _initBoundsForEntries(entries: entries, recentCount: (recentCount ?? 10000) ~/ 10);
    }
    return bounds;
  }

  void _onCollectionChanged() {
    _defaultMarkerCluster = _buildFluster();
    _slowMarkerCluster = null;
    _clusterChangeNotifier.notify();
    _updateItemTracks();
  }

  void _updateItemTracks() {
    final tracks = [...?widget.tracks];
    if (settings.mapShowItemTracks) {
      final entries = widget.collection?.sortedEntries;
      if (entries != null && entries.isNotEmpty) {
        final itemTrackPoints = <List<LatLng>>[];
        var prevDate = DateTime.fromMillisecondsSinceEpoch(0);
        var prevLatLng = const LatLng(0, 0);
        final currentTrack = <LatLng>[];
        for (final entry in entries.sorted(FmvEntrySort.compareByDate).reversed) {
          final thisDate = entry.bestDate;
          if (thisDate != null) {
            if (thisDate.difference(prevDate) > maxTrackPointInterval) {
              itemTrackPoints.add(List.unmodifiable(currentTrack));
              currentTrack.clear();
            }
            final latLng = entry.latLng;
            if (latLng != null) {
              if (prevLatLng != latLng) {
                currentTrack.add(latLng);
                prevLatLng = latLng;
              }
            }
            prevDate = thisDate;
          }
        }
        itemTrackPoints.add(List.unmodifiable(currentTrack));
        itemTrackPoints.removeWhere((v) => v.length < minTrackPointCount);

        tracks.addAll(GeoTrack.buildTracks(itemTrackPoints));
      }
    }
    _tracksNotifier.value = tracks;
  }

  Fluster<GeoEntry<FmvEntry>> _buildFluster({int nodeSize = 64}) {
    final markers = entries
        .map((entry) {
          final latLng = entry.latLng;
          return latLng != null
              ? GeoEntry<FmvEntry>(
                  entry: entry,
                  latitude: latLng.latitude,
                  longitude: latLng.longitude,
                  markerId: entry.uri,
                )
              : null;
        })
        .nonNulls
        .toList();

    return Fluster<GeoEntry<FmvEntry>>(
      // we keep clustering on the whole range of zooms (including the maximum)
      // to avoid collocated entries overlapping
      minZoom: 0,
      maxZoom: 22,
      // TODO TLAD [map] derive `radius` / `extent`, from device pixel ratio and marker extent?
      // (radius=120, extent=2 << 8) is equivalent to (radius=240, extent=2 << 9)
      radius: 240,
      extent: 2 << 9,
      // node size: 64 by default, higher means faster indexing but slower search
      nodeSize: nodeSize,
      points: markers,
      // use lambda instead of tear-off because of runtime exception when using
      // `T Function(BaseCluster, double, double)` for `T Function(BaseCluster?, double?, double?)`
      createCluster: (BaseCluster? base, double? lng, double? lat) {
        if (base != null && lng != null && lat != null) {
          return GeoEntry<FmvEntry>.createCluster(base, lng, lat);
        }
        throw Exception('Cluster creation arguments should not be null: base=$base lng=$lng, lat=$lat');
      },
    );
  }

  Map<MarkerKey<FmvEntry>, GeoEntry<FmvEntry>> _buildMarkerClusters() {
    final bounds = _boundsNotifier.value;
    final geoEntries = _defaultMarkerCluster?.clusters(bounds.boundingBox, bounds.zoom.round()) ?? [];
    return Map.fromEntries(
      geoEntries.map((v) {
        if (v.isCluster!) {
          final uri = v.childMarkerId;
          final entry = entries.firstWhere((v) => v.uri == uri);
          return MapEntry(MarkerKey(entry, v.pointsSize), v);
        }
        return MapEntry(MarkerKey(v.entry!, null), v);
      }),
    );
  }

  Set<FmvEntry> _getClusterEntries(GeoEntry<FmvEntry> geoEntry) {
    final clusterId = geoEntry.clusterId;
    if (clusterId == null) {
      return {geoEntry.entry!};
    }

    var points = _defaultMarkerCluster?.points(clusterId) ?? [];
    if (points.length != geoEntry.pointsSize) {
      // `Fluster.points()` method does not always return all the points contained in a cluster
      // the higher `nodeSize` is, the higher the chance to get all the points (i.e. as many as the cluster `pointsSize`)
      _slowMarkerCluster ??= _buildFluster(nodeSize: smallestPowerOf2(entries.length).toInt());
      points = _slowMarkerCluster!.points(clusterId);
      assert(points.length == geoEntry.pointsSize, 'got ${points.length}/${geoEntry.pointsSize} for geoEntry=$geoEntry');
    }
    return points.map((geoEntry) => geoEntry.entry!).toSet();
  }

  void _onMarkerTap(GeoEntry<FmvEntry> geoEntry) {
    final onTap = widget.onMarkerTap;
    if (onTap == null) return;

    final clusterId = geoEntry.clusterId;
    FmvEntry? markerEntry;
    if (clusterId != null) {
      final uri = geoEntry.childMarkerId;
      markerEntry = entries.firstWhereOrNull((v) => v.uri == uri);
    } else {
      markerEntry = geoEntry.entry;
    }
    if (markerEntry == null) return;

    final markerLocation = LatLng(geoEntry.latitude!, geoEntry.longitude!);
    onTap(markerLocation, markerEntry);
  }

  Future<void> _onMarkerLongPress({
    required GeoEntry<FmvEntry> geoEntry,
    required LatLng tapLocation,
    required double devicePixelRatio,
  }) async {
    final onMarkerLongPress = widget.onMarkerLongPress;
    if (onMarkerLongPress == null) return;

    final clusterEntries = _getClusterEntries(geoEntry);
    final tapLocalPosition = _boundsNotifier.value.offset(tapLocation);

    FmvEntry markerEntry;
    if (geoEntry.isCluster!) {
      final uri = geoEntry.childMarkerId;
      markerEntry = entries.firstWhere((v) => v.uri == uri);
    } else {
      markerEntry = geoEntry.entry!;
    }
    final countFormatter = settings.fmvLocale.decimalNumberFormat().format;
    final markerLocation = LatLng(geoEntry.latitude!, geoEntry.longitude!);
    Widget markerBuilder(BuildContext context) => ImageMarker(
      count: geoEntry.pointsSize,
      countFormatter: countFormatter,
      drawArrow: false,
      buildThumbnailImage: (extent) => ThumbnailImage(
        entry: markerEntry,
        extent: extent,
        devicePixelRatio: devicePixelRatio,
      ),
    );
    onMarkerLongPress(
      markerLocation,
      markerEntry,
      clusterEntries,
      tapLocalPosition,
      markerBuilder,
    );
  }

  Widget _decorateMap(BuildContext context, Widget? child) => MapDecorator(child: child!);

  Widget _buildButtonPanel(BuildContext context) {
    if (settings.useTvLayout) return const SizedBox();
    return MapButtonPanel(
      controller: widget.controller,
      boundsNotifier: _boundsNotifier,
      openMapPage: widget.openMapPage,
    );
  }
}

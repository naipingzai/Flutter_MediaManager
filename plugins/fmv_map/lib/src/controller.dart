import 'dart:async';

import 'package:fmv_map/src/zoomed_bounds.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:leak_tracker/leak_tracker.dart';

class FmvMapController {
  final StreamController<FmvMapEvent> _streamController = StreamController.broadcast();
  ZoomedBounds? _idleBounds;

  ZoomedBounds? get idleBounds => _idleBounds;

  Stream<FmvMapEvent> get _events => _streamController.stream;

  Stream<MapControllerMoveEvent> get moveCommands => _events.where((event) => event is MapControllerMoveEvent).cast<MapControllerMoveEvent>();

  Stream<MapControllerZoomEvent> get zoomCommands => _events.where((event) => event is MapControllerZoomEvent).cast<MapControllerZoomEvent>();

  Stream<MapControllerRotationResetEvent> get rotationResetCommands => _events.where((event) => event is MapControllerRotationResetEvent).cast<MapControllerRotationResetEvent>();

  Stream<MapIdleUpdate> get idleUpdates => _events.where((event) => event is MapIdleUpdate).cast<MapIdleUpdate>();

  Stream<MapMarkerLocationChangeEvent> get markerLocationChanges => _events.where((event) => event is MapMarkerLocationChangeEvent).cast<MapMarkerLocationChangeEvent>();

  FmvMapController() {
    if (kFlutterMemoryAllocationsEnabled) {
      LeakTracking.dispatchObjectCreated(
        library: 'fmv',
        className: '$FmvMapController',
        object: this,
      );
    }
  }

  void dispose() {
    if (kFlutterMemoryAllocationsEnabled) {
      LeakTracking.dispatchObjectDisposed(object: this);
    }
    _streamController.close();
  }

  void moveTo(LatLng latLng) => _streamController.add(MapControllerMoveEvent(latLng));

  void zoomBy(double delta) => _streamController.add(MapControllerZoomEvent(delta));

  void resetRotation() => _streamController.add(MapControllerRotationResetEvent());

  void notifyIdle(ZoomedBounds bounds) {
    _idleBounds = bounds;
    _streamController.add(MapIdleUpdate(bounds));
  }

  void notifyMarkerLocationChange() => _streamController.add(MapMarkerLocationChangeEvent());
}

abstract class FmvMapEvent {}

class MapControllerMoveEvent extends FmvMapEvent {
  final LatLng latLng;

  MapControllerMoveEvent(this.latLng);
}

class MapControllerZoomEvent extends FmvMapEvent {
  final double delta;

  MapControllerZoomEvent(this.delta);
}

class MapControllerRotationResetEvent extends FmvMapEvent {}

class MapIdleUpdate extends FmvMapEvent {
  final ZoomedBounds bounds;

  MapIdleUpdate(this.bounds);
}

class MapMarkerLocationChangeEvent extends FmvMapEvent {}

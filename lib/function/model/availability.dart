import 'package:flutter_media_view/function/function_device.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:fmv_map/flutter_media_view_map.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

abstract class FmvAvailability {
  Future<void> onNewIntent();

  void onResume();

  bool get isLocked;

  Future<bool> get isConnected;

  Future<bool> get canLocatePlaces;

  List<EntryMapStyle> get mapStyles;
}

class LiveFmvAvailability implements FmvAvailability {
  bool? _isConnected, _isLocked;

  LiveFmvAvailability() {
    Connectivity().onConnectivityChanged.listen(_updateConnectivityFromResult);
  }

  @override
  Future<void> onNewIntent() async {
    _isLocked = await deviceService.isLocked();
    debugPrint('Device is locked=$_isLocked');
  }

  @override
  void onResume() => _isConnected = null;

  @override
  bool get isLocked => _isLocked ?? false;

  @override
  Future<bool> get isConnected async {
    if (_isConnected != null) return SynchronousFuture(_isConnected!);
    final result = await (Connectivity().checkConnectivity());
    _updateConnectivityFromResult(result);
    return _isConnected!;
  }

  void _updateConnectivityFromResult(List<ConnectivityResult> result) {
    final newValue = result.isNotEmpty && !result.contains(ConnectivityResult.none);
    if (_isConnected != newValue) {
      _isConnected = newValue;
      debugPrint('Device is connected=$_isConnected');
    }
  }

  @override
  Future<bool> get canLocatePlaces async => device.hasGeocoder && await isConnected;

  @override
  List<EntryMapStyle> get mapStyles => [
    ...mobileServices.mapStyles,
    ...EntryMapStyles.baseStyles,
  ];
}

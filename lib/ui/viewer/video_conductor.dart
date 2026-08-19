import 'dart:async';
import 'dart:math';

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_props.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/viewer/video_db_playback_state_handler.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:fmv_video/flutter_media_view_video.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:leak_tracker/leak_tracker.dart';

class VideoConductor {
  final CollectionLens? _collection;
  final List<FmvVideoController> _controllers = [];
  final Map<FmvVideoController, StreamSubscription> _statusSubscriptions = {};
  final Map<FmvVideoController, StreamSubscription> _eventSubscriptions = {};
  final PlaybackStateHandler _playbackStateHandler = DatabasePlaybackStateHandler();

  final ValueNotifier<FmvVideoController?> playingVideoControllerNotifier = ValueNotifier(null);

  static const _defaultMaxControllerCount = 3;

  VideoConductor({this._collection}) {
    if (kFlutterMemoryAllocationsEnabled) {
      LeakTracking.dispatchObjectCreated(
        library: 'fmv',
        className: '$VideoConductor',
        object: this,
      );
    }
  }

  Future<void> dispose() async {
    if (kFlutterMemoryAllocationsEnabled) {
      LeakTracking.dispatchObjectDisposed(object: this);
    }
    await _disposeAll();
    playingVideoControllerNotifier.dispose();
    _controllers.clear();
    if (settings.keepScreenOn == KeepScreenOn.videoPlayback) {
      await windowService.keepScreenOn(false);
    }
  }

  Future<FmvVideoController> getOrCreateController(FmvEntry entry, {int? maxControllerCount}) async {
    var controller = getController(entry);
    if (controller != null) {
      _controllers.remove(controller);
    } else {
      maxControllerCount = max(_defaultMaxControllerCount, maxControllerCount ?? 0);
      while (_controllers.length >= maxControllerCount) {
        await _disposeController(_controllers.removeLast());
      }
      await deviceService.requestGarbageCollection();
      controller = videoControllerFactory.buildController(
        entry,
        playbackStateHandler: _playbackStateHandler,
        settings: settings,
      );
      _statusSubscriptions[controller] = controller.statusStream.listen((event) => _onControllerStatusChanged(entry, controller!, event));
      _eventSubscriptions[controller] = controller.eventStream.listen((event) => _onControllerEvent(entry, controller!, event));
    }
    _controllers.insert(0, controller);
    return controller;
  }

  FmvVideoController? getPlayingController() => _controllers.firstWhereOrNull((c) => c.isPlaying);

  FmvVideoController? getController(FmvEntry entry) {
    return _controllers.firstWhereOrNull((c) => c.entry.uri == entry.uri && c.entry.pageId == entry.pageId);
  }

  Future<void> _onControllerStatusChanged(FmvEntry entry, FmvVideoController controller, VideoStatus status) async {
    bool canSkipToNext = false, canSkipToPrevious = false;
    final entries = _collection?.sortedEntries;
    if (entries != null) {
      final currentIndex = entries.indexOf(entry);
      if (currentIndex != -1) {
        bool isVideo(FmvEntry entry) => entry.isVideo;
        canSkipToPrevious = entries.take(currentIndex).lastWhereOrNull(isVideo) != null;
        canSkipToNext = entries.skip(currentIndex + 1).firstWhereOrNull(isVideo) != null;
      }
    }

    await mediaSessionService.update(
      entry: entry,
      controller: controller,
      canSkipToNext: canSkipToNext,
      canSkipToPrevious: canSkipToPrevious,
    );
    if (settings.keepScreenOn == KeepScreenOn.videoPlayback) {
      await windowService.keepScreenOn(status == VideoStatus.playing);
    }

    playingVideoControllerNotifier.value = getPlayingController();
  }

  Future<void> _onControllerEvent(FmvEntry entry, FmvVideoController controller, VideoEvent event) async {
    if (event is LagEvent) {
      debugPrint('Video lag detected: disposing video controllers, keeping only the one for entry=$entry');
      final otherControllers = List.of(_controllers)..remove(controller);
      _controllers.removeWhere(otherControllers.contains);
      await Future.forEach<FmvVideoController>(otherControllers, _disposeController);
    }
  }

  Future<void> _applyToAll(Future Function(FmvVideoController controller) action) {
    // local copy to prevent concurrent modification
    return Future.forEach<FmvVideoController>(List.of(_controllers), action);
  }

  Future<void> _disposeAll() => _applyToAll(_disposeController);

  Future<void> pauseAll() => _applyToAll((controller) => controller.pause());

  Future<void> muteAll(bool muted) => _applyToAll((controller) => controller.mute(muted));

  Future<void> _disposeController(FmvVideoController controller) async {
    await _statusSubscriptions.remove(controller)?.cancel();
    await _eventSubscriptions.remove(controller)?.cancel();
    await controller.dispose();
  }
}

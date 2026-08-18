import 'dart:async';
import 'dart:math';

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_keys.dart';
import 'package:flutter_media_view/function/entry/extensions_location.dart';
import 'package:flutter_media_view/function/entry/extensions_props.dart';
import 'package:flutter_media_view/function/filters/covered_stored_album.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/function/media/enums.dart';
import 'package:flutter_media_view/function/utils/android_file_utils.dart';
import 'package:flutter_media_view/ui/collection/widgets_collection_collection_page.dart';
import 'package:flutter_media_view/ui/common/common_action_mixins_feedback.dart';
import 'package:flutter_media_view/ui/common/common_action_mixins_permission_aware.dart';
import 'package:flutter_media_view/ui/common/common_action_mixins_size_aware.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/dialogs_aves_dialog.dart';
import 'package:flutter_media_view/ui/common/dialogs_video_speed_dialog.dart';
import 'package:flutter_media_view/ui/common/dialogs_video_track_selection_dialog.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_video_video_settings_page.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_controls_notifications.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter_media_view_video/flutter_media_view_video.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:leak_tracker/leak_tracker.dart';

class VideoActionDelegate with FeedbackMixin, PermissionAwareMixin, SizeAwareMixin {
  final CollectionLens? collection;

  VideoActionDelegate({
    required this.collection,
  }) {
    if (kFlutterMemoryAllocationsEnabled) {
      LeakTracking.dispatchObjectCreated(
        library: 'aves',
        className: '$VideoActionDelegate',
        object: this,
      );
    }
  }

  void dispose() {
    if (kFlutterMemoryAllocationsEnabled) {
      LeakTracking.dispatchObjectDisposed(object: this);
    }
  }

  Future<void> onActionSelected(BuildContext context, AvesEntry entry, AvesVideoController controller, EntryAction action) async {
    // make sure overlay is not disappearing when selecting an action
    const ToggleOverlayNotification(visible: true).dispatch(context);

    switch (action) {
      case .videoCaptureFrame:
        await _captureFrame(context, entry, controller);
      case .videoToggleMute:
        await controller.mute(!controller.isMuted);
      case .videoSelectTracks:
        await _showTrackSelectionDialog(context, controller);
      case .videoSetSpeed:
        await _showSpeedDialog(context, controller);
      case .videoABRepeat:
        controller.toggleABRepeat();
      case .videoSettings:
        await _showSettings(context, controller);
      case .videoTogglePlay:
        await _togglePlayPause(context, controller);
      case .videoReplay10:
        await controller.seekTo(max(controller.currentPosition - 10000, 0));
      case .videoSkip10:
        await controller.seekTo(controller.currentPosition + 10000);
      case .videoShowPreviousFrame:
        await controller.skipFrames(-1);
      case .videoShowNextFrame:
        await controller.skipFrames(1);
      case .openVideoPlayer:
        await appService.open(entry.uri, entry.mimeTypeAnySubtype, forceChooser: false).then((success) {
          if (!success) showNoMatchingAppDialog(context);
        });
      default:
        throw UnsupportedError('$action is not a video action');
    }
  }

  Future<void> _captureFrame(BuildContext context, AvesEntry entry, AvesVideoController controller) async {
    final destinationAlbum = androidFileUtils.avesVideoCapturesPath;
    final positionMillis = controller.currentPosition;
    final Map<String, dynamic> newFields = {};

    final bytes = await controller.captureFrame();
    if (bytes != null) {
      if (!await checkStoragePermissionForAlbums(context, {destinationAlbum})) return;

      if (!await checkFreeSpace(context, bytes.length, destinationAlbum)) return;

      final rotationDegrees = entry.rotationDegrees;
      final dateTimeMillis = entry.catalogMetadata?.dateMillis;
      final latLng = entry.latLng;
      final exif = <String, num>{
        if (rotationDegrees != 0) 'rotationDegrees': rotationDegrees,
        if (dateTimeMillis != null && dateTimeMillis != 0) 'dateTimeMillis': dateTimeMillis,
        if (latLng != null) ...{
          'latitude': latLng.latitude,
          'longitude': latLng.longitude,
        },
      };

      newFields.addAll(
        await mediaEditService.captureFrame(
          entry,
          desiredName: '${entry.bestTitle}_${'$positionMillis'.padLeft(8, '0')}',
          exif: exif,
          bytes: bytes,
          destinationAlbum: destinationAlbum,
          nameConflictStrategy: NameConflictStrategy.rename,
        ),
      );
    }
    final success = newFields.isNotEmpty;

    final l10n = context.l10n;
    if (success) {
      final _collection = collection;
      // get navigator beforehand because
      // local context may be deactivated when action is triggered after navigation
      final navigator = Navigator.maybeOf(context);
      final showAction = _collection != null
          ? SnackBarAction(
              label: l10n.showButtonLabel,
              onPressed: () {
                if (navigator != null) {
                  final source = _collection.source;
                  final newUri = newFields[EntryFields.uri] as String?;
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(
                      settings: const RouteSettings(name: CollectionPage.routeName),
                      builder: (context) => CollectionPage(
                        source: source,
                        filters: {StoredAlbumFilter(destinationAlbum, source.getStoredAlbumDisplayName(context, destinationAlbum))},
                        highlightTest: (entry) => entry.uri == newUri,
                      ),
                    ),
                    (route) => false,
                  );
                }
              },
            )
          : null;
      showFeedback(context, FeedbackType.info, l10n.genericSuccessFeedback, showAction);
    } else {
      showFeedback(context, FeedbackType.warn, l10n.genericFailureFeedback);
    }
  }

  Future<void> _showTrackSelectionDialog(BuildContext context, AvesVideoController controller) async {
    final tracks = controller.tracks;
    final currentSelectedTracks = await Future.wait(MediaTrackType.values.map(controller.getSelectedTrack));

    final userSelectedTracks = await showAvesDialog<Map<MediaTrackType, MediaTrackSummary?>>(
      context: context,
      builder: (context) => VideoTrackSelectionDialog(
        tracks: Map.fromEntries(
          tracks.map((track) {
            final selectedTrack = currentSelectedTracks.nonNulls.firstWhereOrNull((v) => v.type == track.type);
            final selected = selectedTrack != null && selectedTrack.index == track.index;
            return MapEntry(track, selected);
          }),
        ),
      ),
      routeSettings: const RouteSettings(name: VideoTrackSelectionDialog.routeName),
    );
    if (userSelectedTracks == null || userSelectedTracks.isEmpty) return;

    await Future.forEach<MapEntry<MediaTrackType, MediaTrackSummary?>>(
      userSelectedTracks.entries,
      (kv) => controller.selectTrack(kv.key, kv.value),
    );
  }

  Future<void> _showSpeedDialog(BuildContext context, AvesVideoController controller) async {
    final newSpeed = await showAvesDialog<double>(
      context: context,
      builder: (context) => VideoSpeedDialog(
        current: controller.speed,
        min: controller.minSpeed,
        max: controller.maxSpeed,
      ),
      routeSettings: const RouteSettings(name: VideoSpeedDialog.routeName),
    );
    if (newSpeed == null) return;

    await controller.setSpeed(newSpeed);
  }

  Future<void> _showSettings(BuildContext context, AvesVideoController controller) async {
    int? resumePosition;
    if (controller.isPlaying) {
      resumePosition = controller.currentPosition;
      await controller.pause();
    }
    await Navigator.maybeOf(context)?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: VideoSettingsPage.routeName),
        builder: (context) => const VideoSettingsPage(),
      ),
    );
    if (resumePosition != null) {
      if (!controller.isReady) {
        await controller.seekTo(resumePosition);
      }
      await controller.play();
    }
  }

  Future<void> _togglePlayPause(BuildContext context, AvesVideoController controller) async {
    if (!context.mounted) return;

    if (controller.isPlaying) {
      await controller.pause();
    } else {
      final resumeTimeMillis = await controller.getResumeTime(context);
      if (resumeTimeMillis != null) {
        await controller.seekTo(resumeTimeMillis);
      } else {
        await controller.play();
      }
    }
  }
}

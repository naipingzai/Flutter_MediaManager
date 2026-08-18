import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter_media_view_video/flutter_media_view_video.dart';
import 'package:flutter_media_view_video_mpv/flutter_media_view_video_mpv.dart';
import 'package:media_kit/media_kit.dart';

class MpvVideoControllerFactory extends AvesVideoControllerFactory {
  @override
  void init() => MediaKit.ensureInitialized();

  @override
  AvesVideoController buildController(
    AvesEntryBase entry, {
    required PlaybackStateHandler playbackStateHandler,
    required VideoSettings settings,
  }) => MpvVideoController(
    entry,
    playbackStateHandler: playbackStateHandler,
    settings: settings,
  );
}

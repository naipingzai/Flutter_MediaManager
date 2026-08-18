import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter_media_view_video/flutter_media_view_video.dart';
import 'package:flutter_media_view_video_exo/flutter_media_view_video_exo.dart';

class ExoVideoControllerFactory extends AvesVideoControllerFactory {
  @override
  void init() {}

  @override
  AvesVideoController buildController(
    AvesEntryBase entry, {
    required PlaybackStateHandler playbackStateHandler,
    required VideoSettings settings,
  }) => ExoVideoController(
    entry,
    playbackStateHandler: playbackStateHandler,
    settings: settings,
  );
}

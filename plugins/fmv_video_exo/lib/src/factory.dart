import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:fmv_video/flutter_media_view_video.dart';
import 'package:fmv_video_exo/flutter_media_view_video_exo.dart';

class ExoVideoControllerFactory extends FmvVideoControllerFactory {
  @override
  void init() {}

  @override
  FmvVideoController buildController(
    FmvEntryBase entry, {
    required PlaybackStateHandler playbackStateHandler,
    required VideoSettings settings,
  }) => ExoVideoController(
    entry,
    playbackStateHandler: playbackStateHandler,
    settings: settings,
  );
}

import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:fmv_video/flutter_media_view_video.dart';
import 'package:fmv_video_mpv/flutter_media_view_video_mpv.dart';
import 'package:media_kit/media_kit.dart';

class MpvVideoControllerFactory extends FmvVideoControllerFactory {
  @override
  void init() => MediaKit.ensureInitialized();

  @override
  FmvVideoController buildController(
    FmvEntryBase entry, {
    required PlaybackStateHandler playbackStateHandler,
    required VideoSettings settings,
  }) => MpvVideoController(
    entry,
    playbackStateHandler: playbackStateHandler,
    settings: settings,
  );
}

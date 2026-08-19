import 'dart:async';

import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/function/locale/locales.dart';
import 'package:fmv/ui/theme/format.dart';
import 'package:fmv/ui/theme/icons.dart';
import 'package:fmv/ui/theme/styles.dart';
import 'package:fmv/ui/theme/themes.dart';
import 'package:fmv/ui/common/extensions_theme.dart';
import 'package:fmv/ui/common/fx_blurred.dart';
import 'package:fmv/ui/common/fx_borders.dart';
import 'package:fmv_utils/flutter_media_view_utils.dart';
import 'package:fmv_video/flutter_media_view_video.dart';
import 'package:decorated_icon/decorated_icon.dart';
import 'package:flutter/material.dart';

class VideoProgressBar extends StatefulWidget {
  final FmvVideoController? controller;
  final Animation<double> scale;

  static const padding = EdgeInsets.symmetric(horizontal: 16);

  const VideoProgressBar({
    super.key,
    required this.controller,
    required this.scale,
  });

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  final GlobalKey _progressBarKey = GlobalKey(debugLabel: 'video-progress-bar');
  bool _playingOnDragStart = false;

  static const double _radius = 123;
  static const double _abRepeatMarkWidth = 2;

  FmvVideoController? get controller => widget.controller;

  Stream<int> get positionStream => controller?.positionStream ?? Stream.value(0);

  bool get isPlaying => controller?.isPlaying ?? false;

  bool get isSlowMotion => controller?.isSlowMotion ?? false;

  ValueNotifier<ABRepeat?>? get abRepeatNotifier => controller?.abRepeatNotifier;

  ValueNotifier<SlowMotionRange>? get slowMotionRangeNotifier => controller?.slowMotionRangeNotifier;

  @override
  Widget build(BuildContext context) {
    final blurred = settings.enableBlurEffect;
    final theme = Theme.of(context);
    return SizeTransition(
      sizeFactor: widget.scale,
      child: BlurredRRect.all(
        enabled: blurred,
        borderRadius: _radius,
        child: GestureDetector(
          onTapDown: (details) {
            _seekFromTap(details.globalPosition);
          },
          onHorizontalDragStart: (details) {
            _playingOnDragStart = isPlaying;
            if (_playingOnDragStart) controller?.pause();
          },
          onHorizontalDragUpdate: (details) {
            _seekFromTap(details.globalPosition);
          },
          onHorizontalDragEnd: (details) {
            if (_playingOnDragStart) controller?.play();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
            child: Container(
              padding: VideoProgressBar.padding,
              decoration: BoxDecoration(
                color: Themes.overlayBackgroundColor(brightness: theme.brightness, blurred: blurred),
                border: FmvBorder.border(context),
                borderRadius: const BorderRadius.all(Radius.circular(_radius)),
              ),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.noScaling,
                ),
                child: NullableValueListenableBuilder<ABRepeat?>(
                  valueListenable: abRepeatNotifier,
                  builder: (context, abRepeat, child) {
                    return Stack(
                      fit: StackFit.passthrough,
                      children: [
                        if (abRepeat != null) ...[
                          _buildABRepeatMark(context, abRepeat.start),
                          _buildABRepeatMark(context, abRepeat.end),
                        ],
                        Container(
                          key: _progressBarKey,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: .min,
                            children: [
                              Row(
                                children: [
                                  StreamBuilder<int>(
                                    stream: positionStream,
                                    builder: (context, snapshot) {
                                      // do not use stream snapshot because it is obsolete when switching between videos
                                      final position = controller?.currentPosition.floor() ?? 0;
                                      return _buildText(formatFriendlyDuration(Duration(milliseconds: position)));
                                    },
                                  ),
                                  const Spacer(),
                                  _buildText(formatFriendlyDuration(Duration(milliseconds: controller?.duration ?? 0))),
                                ],
                              ),
                              ClipRRect(
                                borderRadius: const BorderRadius.all(Radius.circular(4)),
                                child: Directionality(
                                  textDirection: kVideoPlaybackDirection,
                                  child: StreamBuilder<int>(
                                    stream: positionStream,
                                    builder: (context, snapshot) {
                                      // do not use stream snapshot because it is obsolete when switching between videos
                                      var progress = controller?.progress ?? 0.0;
                                      if (!progress.isFinite) progress = 0.0;
                                      return LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: .2),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  if (!isSlowMotion) _buildSpeedIndicator(),
                                  _buildMuteIndicator(),
                                  // fake text below to match the height of the text above and center the whole thing
                                  _buildText(''),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildText(String text) {
    return Text(
      text,
      style: TextStyle(
        shadows: Theme.of(context).isDark ? AStyles.embossShadows : null,
      ),
      strutStyle: const StrutStyle(
        forceStrutHeight: true,
      ),
    );
  }

  Widget _buildABRepeatMark(BuildContext context, int? position) {
    if (controller == null || position == null) return const SizedBox();
    final dx = _progressToDx(position / controller!.duration);
    return Positioned(
      left: dx != null ? dx - _abRepeatMarkWidth / 2 : null,
      top: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: FmvBorder.straightSide(context, width: _abRepeatMarkWidth)),
        ),
      ),
    );
  }

  Widget _buildSpeedIndicator() => StreamBuilder<double>(
    stream: controller?.speedStream ?? Stream.value(1.0),
    builder: (context, snapshot) {
      final speed = controller?.speed ?? 1.0;
      return speed != 1
          ? Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _buildText('x${roundToPrecision(speed, decimals: 3)}'),
            )
          : const SizedBox();
    },
  );

  Widget _buildMuteIndicator() => StreamBuilder<double>(
    stream: controller?.volumeStream ?? Stream.value(1.0),
    builder: (context, snapshot) {
      final textScaler = MediaQuery.textScalerOf(context);
      final isMuted = controller?.isMuted ?? false;
      return isMuted
          ? Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: DecoratedIcon(
                AIcons.mute,
                size: textScaler.scale(16),
                shadows: Theme.of(context).isDark ? AStyles.embossShadows : null,
              ),
            )
          : const SizedBox();
    },
  );

  void _seekFromTap(Offset globalPosition) async {
    final box = _getProgressBarRenderBox();
    if (controller == null || box == null) return;

    final dx = box.globalToLocal(globalPosition).dx;
    await controller!.seekToProgress(dx / box.size.width);
  }

  double? _progressToDx(double progress) {
    final box = _getProgressBarRenderBox();
    return box != null && box.hasSize ? progress * box.size.width : null;
  }

  RenderBox? _getProgressBarRenderBox() {
    return _progressBarKey.currentContext?.findRenderObject() as RenderBox?;
  }
}

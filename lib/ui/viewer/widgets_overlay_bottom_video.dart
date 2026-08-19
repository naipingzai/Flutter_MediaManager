import 'dart:async';

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/common/view.dart';
import 'package:flutter_media_view/ui/common/identity/common_identity_buttons_overlay_button.dart';
import 'package:flutter_media_view/ui/viewer/widgets_overlay_bottom.dart';
import 'package:flutter_media_view/ui/viewer/widgets_overlay_bottom_video_ab_repeat.dart';
import 'package:flutter_media_view/ui/viewer/widgets_overlay_bottom_video_controls.dart';
import 'package:flutter_media_view/ui/viewer/widgets_overlay_bottom_video_progress_bar.dart';
import 'package:flutter_media_view/ui/viewer/widgets_overlay_bottom_video_slow_motion_bar.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:fmv_video/flutter_media_view_video.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VideoControlOverlay extends StatefulWidget {
  final FmvEntry entry;
  final FmvVideoController? controller;
  final Animation<double> scale;
  final Function(EntryAction value) onActionSelected;

  const VideoControlOverlay({
    super.key,
    required this.entry,
    required this.controller,
    required this.scale,
    required this.onActionSelected,
  });

  @override
  State<StatefulWidget> createState() => _VideoControlOverlayState();
}

class _VideoControlOverlayState extends State<VideoControlOverlay> with SingleTickerProviderStateMixin {
  FmvEntry get entry => widget.entry;

  Animation<double> get scale => widget.scale;

  FmvVideoController? get controller => widget.controller;

  Stream<VideoStatus> get statusStream => controller?.statusStream ?? Stream.value(VideoStatus.idle);

  static const double _padding = 8;
  static const double _progressOverControlsWidthThreshold = 160;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VideoStatus>(
      stream: statusStream,
      builder: (context, snapshot) {
        // do not use stream snapshot because it is obsolete when switching between videos
        final status = controller?.status ?? VideoStatus.idle;

        if (status == VideoStatus.error) {
          const action = EntryAction.openVideoPlayer;
          return Align(
            alignment: Alignment.centerRight,
            child: OverlayButton(
              scale: scale,
              child: IconButton(
                icon: action.getIcon(),
                onPressed: entry.trashed ? null : () => widget.onActionSelected(action),
                tooltip: action.getText(context),
              ),
            ),
          );
        }

        Widget progressBar = VideoProgressBar(
          controller: controller,
          scale: scale,
        );
        if (controller?.isSlowMotion ?? false) {
          progressBar = Column(
            children: [
              SlowMotionBar(
                controller: controller,
                scale: scale,
              ),
              const SizedBox(height: 8),
              progressBar,
            ],
          );
        }
        final controls = VideoControlRow(
          controller: controller,
          scale: scale,
          canOpenVideoPlayer: !entry.trashed,
          onActionSelected: widget.onActionSelected,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            var progressOverControls = false;
            final actions = context.select<Settings, List<EntryAction>>((v) => v.videoControlActions);
            if (actions.isNotEmpty) {
              final availableWidth = constraints.maxWidth - _padding - VideoControlRow.computeWidth(context, actions);
              progressOverControls = availableWidth < _progressOverControlsWidthThreshold;
            }
            final progressAndControls = progressOverControls
                ? [
                    progressBar,
                    const SizedBox(height: _padding),
                    controls,
                  ]
                : [
                    Row(
                      crossAxisAlignment: .end,
                      textDirection: ViewerBottomOverlay.actionsDirection,
                      children: [
                        Expanded(child: progressBar),
                        if (actions.isNotEmpty) const SizedBox(width: _padding),
                        controls,
                      ],
                    ),
                  ];
            return Column(
              crossAxisAlignment: .end,
              textDirection: ViewerBottomOverlay.actionsDirection,
              children: [
                VideoABRepeatOverlay(
                  controller: controller,
                  scale: scale,
                ),
                const SizedBox(height: _padding),
                ...progressAndControls,
              ],
            );
          },
        );
      },
    );
  }
}

import 'dart:async';

import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_popup_menu_row.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/identity/common_identity_buttons_captioned_button.dart';
import 'package:fmv_video/flutter_media_view_video.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PlayToggler extends StatefulWidget {
  final FmvVideoController? controller;
  final bool isMenuItem;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;

  const PlayToggler({
    super.key,
    required this.controller,
    this.isMenuItem = false,
    this.focusNode,
    this.onPressed,
  });

  @override
  State<PlayToggler> createState() => _PlayTogglerState();
}

class _PlayTogglerState extends State<PlayToggler> with SingleTickerProviderStateMixin {
  final Set<StreamSubscription> _subscriptions = {};
  late AnimationController _playPauseAnimation;

  FmvVideoController? get controller => widget.controller;

  bool get isPlaying => controller?.isPlaying ?? false;

  @override
  void initState() {
    super.initState();
    _playPauseAnimation = AnimationController(
      duration: context.read<DurationsData>().iconAnimation,
      vsync: this,
    );
    _registerWidget(widget);
  }

  @override
  void didUpdateWidget(covariant PlayToggler oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
  }

  @override
  void dispose() {
    _unregisterWidget(widget);
    _playPauseAnimation.dispose();
    super.dispose();
  }

  void _registerWidget(PlayToggler widget) {
    final controller = widget.controller;
    if (controller != null) {
      _subscriptions.add(controller.statusStream.listen(_onStatusChanged));
      _onStatusChanged(controller.status);
    }
  }

  void _unregisterWidget(PlayToggler widget) {
    _subscriptions
      ..forEach((sub) => sub.cancel())
      ..clear();
  }

  @override
  Widget build(BuildContext context) {
    final text = isPlaying ? context.l10n.videoActionPause : context.l10n.videoActionPlay;

    return widget.isMenuItem
        ? MenuRow(
            text: text,
            icon: Icon(isPlaying ? AIcons.pause : AIcons.play),
          )
        : IconButton(
            icon: AnimatedIcon(
              icon: AnimatedIcons.play_pause,
              progress: _playPauseAnimation,
            ),
            onPressed: widget.onPressed,
            focusNode: widget.focusNode,
            tooltip: text,
          );
  }

  void _onStatusChanged(VideoStatus status) {
    final status = _playPauseAnimation.status;
    if (isPlaying && !status.isForwardOrCompleted) {
      _playPauseAnimation.forward();
    } else if (!isPlaying && status.isForwardOrCompleted) {
      _playPauseAnimation.reverse();
    }
  }
}

class PlayTogglerCaption extends StatelessWidget {
  final FmvVideoController? controller;
  final bool enabled;

  const PlayTogglerCaption({
    super.key,
    required this.controller,
    required this.enabled,
  });

  bool get isPlaying => controller?.isPlaying ?? false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VideoStatus>(
      stream: controller?.statusStream ?? Stream.value(VideoStatus.idle),
      builder: (context, snapshot) {
        return CaptionedButtonText(
          text: isPlaying ? context.l10n.videoActionPause : context.l10n.videoActionPlay,
          enabled: enabled,
        );
      },
    );
  }
}

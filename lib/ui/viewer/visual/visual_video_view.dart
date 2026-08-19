import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:fmv_video/flutter_media_view_video.dart';
import 'package:flutter/material.dart';

class VideoView extends StatefulWidget {
  final FmvEntry entry;
  final FmvVideoController controller;

  const VideoView({
    super.key,
    required this.entry,
    required this.controller,
  });

  @override
  State<StatefulWidget> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  FmvEntry get entry => widget.entry;

  FmvVideoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _registerWidget(widget);
  }

  @override
  void didUpdateWidget(covariant VideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
  }

  @override
  void dispose() {
    _unregisterWidget(widget);
    super.dispose();
  }

  void _registerWidget(VideoView widget) {
    widget.controller.playCompletedListenable.addListener(_onPlayCompleted);
  }

  void _unregisterWidget(VideoView widget) {
    widget.controller.playCompletedListenable.removeListener(_onPlayCompleted);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VideoStatus>(
      stream: controller.statusStream,
      builder: (context, snapshot) => controller.isReady ? controller.buildPlayerWidget(context) : const SizedBox(),
    );
  }

  // not called when looping
  void _onPlayCompleted() => controller.seekTo(0);
}

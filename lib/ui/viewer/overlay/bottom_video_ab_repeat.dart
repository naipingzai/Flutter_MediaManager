import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/identity/identity_buttons_overlay_button.dart';
import 'package:fmv_video/flutter_media_view_video.dart';
import 'package:flutter/material.dart';

class VideoABRepeatOverlay extends StatefulWidget {
  final FmvVideoController? controller;
  final Animation<double> scale;

  const VideoABRepeatOverlay({
    super.key,
    required this.controller,
    required this.scale,
  });

  @override
  State<StatefulWidget> createState() => _VideoABRepeatOverlayState();
}

class _VideoABRepeatOverlayState extends State<VideoABRepeatOverlay> {
  final ValueNotifier<ABRepeat?> _internalAbRepeatNotifier = ValueNotifier(null);

  Animation<double> get scale => widget.scale;

  FmvVideoController? get controller => widget.controller;

  ValueNotifier<ABRepeat?> get abRepeatNotifier => controller?.abRepeatNotifier ?? _internalAbRepeatNotifier;

  @override
  void dispose() {
    _internalAbRepeatNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ValueListenableBuilder<ABRepeat?>(
      valueListenable: abRepeatNotifier,
      builder: (context, abRepeat, child) {
        if (abRepeat == null) return const SizedBox();

        Widget boundButton;
        if (abRepeat.start == null) {
          boundButton = IconButton(
            icon: const Icon(AIcons.setBoundStart),
            onPressed: controller?.setABRepeatStart,
            tooltip: l10n.videoRepeatActionSetStart,
          );
        } else if (abRepeat.end == null) {
          boundButton = IconButton(
            icon: const Icon(AIcons.setBoundEnd),
            onPressed: controller?.setABRepeatEnd,
            tooltip: l10n.videoRepeatActionSetEnd,
          );
        } else {
          boundButton = IconButton(
            icon: const Icon(AIcons.resetBounds),
            onPressed: controller?.resetABRepeat,
            tooltip: l10n.resetTooltip,
          );
        }
        return Row(
          mainAxisSize: .min,
          children: [
            const Spacer(),
            OverlayButton(
              scale: scale,
              child: boundButton,
            ),
            const SizedBox(width: 8),
            OverlayButton(
              scale: scale,
              child: IconButton(
                icon: const Icon(AIcons.repeatOff),
                onPressed: () => controller?.toggleABRepeat(),
                tooltip: l10n.stopTooltip,
              ),
            ),
          ],
        );
      },
    );
  }
}

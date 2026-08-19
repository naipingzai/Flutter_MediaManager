import 'dart:math';

import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/common_extensions_media_query.dart';
import 'package:flutter_media_view/ui/common/identity/common_identity_buttons_overlay_button.dart';
import 'package:flutter_media_view/ui/viewer/widgets_controls_notifications.dart';
import 'package:flutter_media_view/ui/viewer/widgets_overlay_bottom_viewer_buttons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ViewerLockedOverlay extends StatefulWidget {
  final AnimationController animationController;
  final EdgeInsets? viewInsets, viewPadding;

  const ViewerLockedOverlay({
    super.key,
    required this.animationController,
    this.viewInsets,
    this.viewPadding,
  });

  @override
  State<StatefulWidget> createState() => _ViewerLockedOverlayState();
}

class _ViewerLockedOverlayState extends State<ViewerLockedOverlay> {
  late CurvedAnimation _buttonScale;

  @override
  void initState() {
    super.initState();
    _registerWidget(widget);
  }

  @override
  void didUpdateWidget(covariant ViewerLockedOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
  }

  @override
  void dispose() {
    _unregisterWidget(widget);
    super.dispose();
  }

  void _registerWidget(ViewerLockedOverlay widget) {
    _buttonScale = CurvedAnimation(
      parent: widget.animationController,
      // a little bounce at the top
      curve: Curves.easeOutBack,
    );
  }

  void _unregisterWidget(ViewerLockedOverlay widget) {
    _buttonScale.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<MediaQueryData, double>(
      selector: (context, mq) => max(mq.effectiveBottomPadding, mq.systemGestureInsets.bottom),
      builder: (context, mqPaddingBottom, child) {
        final viewInsetsPadding = (widget.viewInsets ?? EdgeInsets.zero) + (widget.viewPadding ?? EdgeInsets.zero);
        return Container(
          alignment: Alignment.bottomRight,
          padding: EdgeInsets.only(bottom: mqPaddingBottom) + const EdgeInsets.all(ViewerButtonRowContent.padding),
          child: SafeArea(
            top: false,
            bottom: false,
            minimum: EdgeInsets.only(
              left: viewInsetsPadding.left,
              right: viewInsetsPadding.right,
            ),
            child: OverlayButton(
              scale: _buttonScale,
              child: IconButton(
                icon: const Icon(AIcons.viewerUnlock),
                onPressed: () => const LockViewNotification(locked: false).dispatch(context),
                tooltip: context.l10n.viewerActionUnlock,
              ),
            ),
          ),
        );
      },
    );
  }
}

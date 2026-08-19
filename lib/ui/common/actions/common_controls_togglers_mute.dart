import 'dart:async';

import 'package:fmv/ui/theme/icons.dart';
import 'package:fmv/ui/common/basic/basic_popup_menu_row.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv/ui/common/identity/identity_buttons_captioned_button.dart';
import 'package:fmv_utils/flutter_media_view_utils.dart';
import 'package:fmv_video/flutter_media_view_video.dart';
import 'package:flutter/material.dart';

class MuteToggler extends StatelessWidget {
  final FmvVideoController? controller;
  final bool isMenuItem;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;

  const MuteToggler({
    super.key,
    required this.controller,
    this.isMenuItem = false,
    this.focusNode,
    this.onPressed,
  });

  bool get isMuted => controller?.isMuted ?? false;

  @override
  Widget build(BuildContext context) {
    return NullableValueListenableBuilder<bool>(
      valueListenable: controller?.canMuteNotifier,
      builder: (context, value, child) {
        final canDo = value ?? false;
        return StreamBuilder<double>(
          stream: controller?.volumeStream ?? Stream.value(1.0),
          builder: (context, snapshot) {
            final icon = Icon(isMuted ? AIcons.unmute : AIcons.mute);
            final text = isMuted ? context.l10n.videoActionUnmute : context.l10n.videoActionMute;

            return isMenuItem
                ? MenuRow(
                    text: text,
                    icon: icon,
                  )
                : IconButton(
                    icon: icon,
                    onPressed: canDo ? onPressed : null,
                    focusNode: focusNode,
                    tooltip: text,
                  );
          },
        );
      },
    );
  }
}

class MuteTogglerCaption extends StatelessWidget {
  final FmvVideoController? controller;
  final bool enabled;

  const MuteTogglerCaption({
    super.key,
    required this.controller,
    required this.enabled,
  });

  bool get isMuted => controller?.isMuted ?? false;

  @override
  Widget build(BuildContext context) {
    return NullableValueListenableBuilder<bool>(
      valueListenable: controller?.canMuteNotifier,
      builder: (context, value, child) {
        final canDo = value ?? false;
        return StreamBuilder<double>(
          stream: controller?.volumeStream ?? Stream.value(1.0),
          builder: (context, snapshot) {
            return CaptionedButtonText(
              text: isMuted ? context.l10n.videoActionUnmute : context.l10n.videoActionMute,
              enabled: canDo && enabled,
            );
          },
        );
      },
    );
  }
}

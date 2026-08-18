import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraAccessibilityAnimations on AccessibilityAnimations {
  bool get animate {
    switch (this) {
      case .system:
        // as of Flutter v2.5.1, the check for `disableAnimations` is unreliable
        // so we cannot use `window.accessibilityFeatures.disableAnimations` nor `MediaQuery.of(context).disableAnimations`
        return !settings.areAnimationsRemoved;
      case .disabled:
        return false;
      case .enabled:
        return true;
    }
  }

  Duration get popUpAnimationDuration => animate ? ADurations.popupMenuAnimation : Duration.zero;

  Duration get popUpAnimationDelay => popUpAnimationDuration + const Duration(milliseconds: ADurations.transitionMarginMillis);

  AnimationStyle get popUpAnimationStyle {
    return animate
        ? AnimationStyle(
            curve: Curves.easeInOutCubic,
            duration: popUpAnimationDuration,
          )
        : AnimationStyle.noAnimation;
  }
}

import 'dart:async';

import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/function/common/services.dart';
import 'package:fmv/ui/theme/durations.dart';
import 'package:fmv/ui/common/behaviour/behaviour_pop_scope.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';

final DoubleBackPopHandler doubleBackPopHandler = DoubleBackPopHandler._private();

class DoubleBackPopHandler extends PopHandler {
  bool _backOnce = false;
  Timer? _backTimer;

  DoubleBackPopHandler._private();

  @override
  bool canPop(BuildContext context) {
    if (context.select<Settings, bool>((v) => !v.mustBackTwiceToExit)) return true;
    if (Navigator.canPop(context)) return true;
    return false;
  }

  @override
  void onPopBlocked(BuildContext context) {
    if (_backOnce) {
      if (Navigator.canPop(context)) {
        Navigator.maybeOf(context)?.pop();
      } else {
        // exit
        reportService.log('Exit by pop');
        PopExitNotification().dispatch(context);
        SystemNavigator.pop();
      }
    } else {
      _backOnce = true;
      _backTimer?.cancel();
      _backTimer = Timer(ADurations.doubleBackTimerDelay, () => _backOnce = false);
      toast(
        context.l10n.doubleBackExitMessage,
        duration: ADurations.doubleBackTimerDelay,
      );
    }
  }
}

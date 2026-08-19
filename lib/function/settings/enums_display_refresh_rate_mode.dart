import 'package:flutter_media_view/function/common/services.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

extension ExtraDisplayRefreshRateMode on DisplayRefreshRateMode {
  Future<void> apply() async {
    if (!Platform.isAndroid) return;
    if (!await windowService.isActivity()) return;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt < 23) return;

    debugPrint('Apply display refresh rate: $name');
    switch (this) {
      case .auto:
        await FlutterDisplayMode.setPreferredMode(DisplayMode.auto);
      case .highest:
        await FlutterDisplayMode.setHighRefreshRate();
      case .lowest:
        await FlutterDisplayMode.setLowRefreshRate();
    }
  }
}

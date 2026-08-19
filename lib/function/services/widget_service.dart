import 'package:fmv/function/common/channel.dart';
import 'package:fmv/function/common/services.dart';
import 'package:flutter/services.dart';

class WidgetService {
  static const _configureChannel = FmvMethodChannel('com.naipingzai/flutter_media_view/widget_configure');
  static const _updateChannel = FmvMethodChannel('com.naipingzai/flutter_media_view/widget_update');

  static Future<bool> configure() async {
    try {
      await _configureChannel.invokeMethod('configure');
      return true;
    } on PlatformException catch (e, stack) {
      await reportService.recordError(e, stack);
    }
    return false;
  }

  static Future<bool> update(int widgetId) async {
    try {
      await _updateChannel.invokeMethod('update', <String, Object?>{
        'widgetId': widgetId,
      });
      return true;
    } on PlatformException catch (e, stack) {
      await reportService.recordError(e, stack);
    }
    return false;
  }
}

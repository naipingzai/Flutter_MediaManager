import 'package:flutter_media_view/function/common/channel.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/services.dart';

class WallpaperService {
  static const _platform = FmvMethodChannel('com.naipingzai/flutter_media_view/wallpaper');

  static Future<bool> set(Uint8List bytes, WallpaperTarget target) async {
    try {
      await _platform.invokeMethod('setWallpaper', <String, Object?>{
        'bytes': bytes,
        'home': {WallpaperTarget.home, WallpaperTarget.homeLock}.contains(target),
        'lock': {WallpaperTarget.lock, WallpaperTarget.homeLock}.contains(target),
      });
      return true;
    } on PlatformException catch (e, stack) {
      await reportService.recordError(e, stack);
    }
    return false;
  }
}

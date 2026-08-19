import 'package:flutter_media_view/core/app_flavor.dart';
import 'package:flutter_media_view/main_common.dart';
import 'package:flutter_media_view/function/settings/app_intent.dart';

// https://developer.android.com/studio/command-line/adb.html#IntentSpec
// adb shell am start -n com.naipingzai.flutter_media_view.debug/com.naipingzai.flutter_media_view.MainActivity -a android.intent.action.EDIT -d content://media/external/images/media/183128 -t image/*

@pragma('vm:entry-point')
void main() => mainCommon(
  AppFlavor.play,
  debugIntentData: {
    IntentDataKeys.action: IntentActions.edit,
    IntentDataKeys.mimeType: 'image/*',
    IntentDataKeys.uri: 'content://media/external/images/media/1000064996', // landscape
    // IntentDataKeys.uri: 'content://media/external/images/media/1000064754', // portrait
  },
);

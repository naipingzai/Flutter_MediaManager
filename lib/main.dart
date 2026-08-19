import 'package:flutter_media_view/core/app_flavor.dart';
import 'package:flutter_media_view/main_common.dart';
import 'package:flutter_media_view/core/widget_common.dart';

// default build entrypoint, mirrors `main_izzy.dart`
const AppFlavor _flavor = .izzy;

@pragma('vm:entry-point')
void main() => mainCommon(_flavor);

@pragma('vm:entry-point')
void widgetMain() => widgetMainCommon(_flavor);

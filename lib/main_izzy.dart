import 'package:flutter_media_view/app_flavor.dart';
import 'package:flutter_media_view/main_common.dart';
import 'package:flutter_media_view/widget_common.dart';

const AppFlavor _flavor = .izzy;

@pragma('vm:entry-point')
void main() => mainCommon(_flavor);

@pragma('vm:entry-point')
void widgetMain() => widgetMainCommon(_flavor);

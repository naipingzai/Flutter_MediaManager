import 'package:fmv/core/app_flavor.dart';
import 'package:fmv/main_common.dart';
import 'package:fmv/core/widget_common.dart';

const AppFlavor _flavor = .izzy;

@pragma('vm:entry-point')
void main() => mainCommon(_flavor);

@pragma('vm:entry-point')
void widgetMain() => widgetMainCommon(_flavor);

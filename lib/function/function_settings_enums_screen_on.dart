import 'package:flutter_media_view/function/function_common_services.dart';
import 'package:aves_model/aves_model.dart';

extension ExtraKeepScreenOn on KeepScreenOn {
  void apply() {
    windowService.keepScreenOn(this == KeepScreenOn.always);
  }
}

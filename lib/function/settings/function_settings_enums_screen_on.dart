import 'package:flutter_media_view/function/common/function_common_services.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';

extension ExtraKeepScreenOn on KeepScreenOn {
  void apply() {
    windowService.keepScreenOn(this == KeepScreenOn.always);
  }
}

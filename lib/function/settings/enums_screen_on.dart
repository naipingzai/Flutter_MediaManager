import 'package:flutter_media_view/function/common/services.dart';
import 'package:fmv_model/flutter_media_view_model.dart';

extension ExtraKeepScreenOn on KeepScreenOn {
  void apply() {
    windowService.keepScreenOn(this == KeepScreenOn.always);
  }
}

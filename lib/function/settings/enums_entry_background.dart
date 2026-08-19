import 'dart:ui';

import 'package:fmv_model/flutter_media_view_model.dart';

extension ExtraEntryBackground on EntryBackground {
  bool get isColor {
    switch (this) {
      case .black:
      case .white:
        return true;
      default:
        return false;
    }
  }

  Color get color {
    switch (this) {
      case .white:
        return const Color(0xFFFFFFFF);
      case .black:
      default:
        return const Color(0xFF000000);
    }
  }
}

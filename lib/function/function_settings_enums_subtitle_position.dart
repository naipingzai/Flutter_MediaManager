import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/painting.dart';

extension ExtraSubtitlePosition on SubtitlePosition {
  TextAlignVertical toTextAlignVertical() {
    switch (this) {
      case .top:
        return TextAlignVertical.top;
      case .bottom:
        return TextAlignVertical.bottom;
    }
  }
}

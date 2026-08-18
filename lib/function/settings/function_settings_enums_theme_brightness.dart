import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

extension ExtraAvesThemeBrightness on AvesThemeBrightness {
  ThemeMode get appThemeMode {
    switch (this) {
      case .system:
        return ThemeMode.system;
      case .light:
        return ThemeMode.light;
      case .dark:
      case .black:
        return ThemeMode.dark;
    }
  }
}

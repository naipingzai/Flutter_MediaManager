import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

extension ExtraFmvThemeBrightness on FmvThemeBrightness {
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

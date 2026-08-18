import 'package:flutter_media_view/ui/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraWallpaperTargetView on WallpaperTarget {
  String getName(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      WallpaperTarget.home => l10n.wallpaperTargetHome,
      WallpaperTarget.lock => l10n.wallpaperTargetLock,
      WallpaperTarget.homeLock => l10n.wallpaperTargetHomeLock,
    };
  }
}

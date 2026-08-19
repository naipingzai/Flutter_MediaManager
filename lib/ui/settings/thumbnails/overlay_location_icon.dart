import 'package:fmv/ui/theme/icons.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraThumbnailOverlayLocationIconView on ThumbnailOverlayLocationIcon {
  String getName(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      ThumbnailOverlayLocationIcon.located => l10n.filterLocatedLabel,
      ThumbnailOverlayLocationIcon.unlocated => l10n.filterNoLocationLabel,
      ThumbnailOverlayLocationIcon.none => l10n.settingsDisabled,
    };
  }

  IconData getIcon(BuildContext context) {
    return switch (this) {
      ThumbnailOverlayLocationIcon.unlocated => AIcons.locationUnlocated,
      ThumbnailOverlayLocationIcon.located || ThumbnailOverlayLocationIcon.none => AIcons.location,
    };
  }
}

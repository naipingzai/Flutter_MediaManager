import 'package:flutter_media_view/ui/theme/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraThumbnailOverlayTagIconView on ThumbnailOverlayTagIcon {
  String getName(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      ThumbnailOverlayTagIcon.tagged => l10n.filterTaggedLabel,
      ThumbnailOverlayTagIcon.untagged => l10n.filterNoTagLabel,
      ThumbnailOverlayTagIcon.none => l10n.settingsDisabled,
    };
  }

  IconData getIcon(BuildContext context) {
    return switch (this) {
      ThumbnailOverlayTagIcon.tagged => AIcons.tag,
      ThumbnailOverlayTagIcon.untagged => AIcons.tagUntagged,
      ThumbnailOverlayTagIcon.none => AIcons.tag,
    };
  }
}

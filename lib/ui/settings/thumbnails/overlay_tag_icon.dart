import 'package:fmv/ui/theme/icons.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
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

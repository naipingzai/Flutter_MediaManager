import 'package:fmv/ui/theme/icons.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraEntryConvertActionView on EntryConvertAction {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      EntryConvertAction.convert => l10n.entryActionConvert,
      EntryConvertAction.convertMotionPhotoToStillImage => l10n.entryActionConvertMotionPhotoToStillImage,
    };
  }

  IconData getIconData() {
    return switch (this) {
      EntryConvertAction.convert => AIcons.convert,
      EntryConvertAction.convertMotionPhotoToStillImage => AIcons.convertToStillImage,
    };
  }
}

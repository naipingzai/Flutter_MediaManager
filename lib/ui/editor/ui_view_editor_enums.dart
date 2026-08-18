import 'package:flutter_media_view/function/function_unicode.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraEditorActionView on EditorAction {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      EditorAction.transform => l10n.editorActionTransform,
    };
  }

  Widget getIcon() => Icon(_getIconData());

  IconData _getIconData() {
    return switch (this) {
      EditorAction.transform => AIcons.transform,
    };
  }
}

extension ExtraCropAspectRatioView on CropAspectRatio {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      CropAspectRatio.free => l10n.cropAspectRatioFree,
      CropAspectRatio.original => l10n.cropAspectRatioOriginal,
      CropAspectRatio.square => l10n.cropAspectRatioSquare,
      CropAspectRatio.ar_16_9 => '16${UniChars.ratio}9',
      CropAspectRatio.ar_4_3 => '4${UniChars.ratio}3',
    };
  }

  Widget getIcon() => Icon(_getIconData());

  IconData _getIconData() {
    return switch (this) {
      CropAspectRatio.free => AIcons.aspectRatioFree,
      CropAspectRatio.original => AIcons.aspectRatioOriginal,
      CropAspectRatio.square => AIcons.aspectRatioSquare,
      CropAspectRatio.ar_16_9 => AIcons.aspectRatio_16_9,
      CropAspectRatio.ar_4_3 => AIcons.aspectRatio_4_3,
    };
  }
}

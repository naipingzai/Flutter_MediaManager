import 'package:flutter_media_view/ui/theme/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraShareActionView on ShareAction {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      .imageOnly => l10n.entryActionShareImageOnly,
      .videoOnly => l10n.entryActionShareVideoOnly,
    };
  }

  Widget getIcon() => Icon(_getIconData());

  IconData _getIconData() {
    return switch (this) {
      .imageOnly => AIcons.image,
      .videoOnly => AIcons.video,
    };
  }
}

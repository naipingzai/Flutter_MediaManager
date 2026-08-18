import 'package:flutter_media_view/ui/theme/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

extension ExtraExplorerActionView on ExplorerAction {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      .addShortcut => l10n.collectionActionAddShortcut,
      .setHome => l10n.collectionActionSetHome,
      .hide => l10n.chipActionHide,
      .stats => l10n.menuActionStats,
    };
  }

  Widget getIcon() => Icon(_getIconData());

  IconData _getIconData() {
    return switch (this) {
      .addShortcut => AIcons.addShortcut,
      .setHome => AIcons.home,
      .hide => AIcons.hide,
      .stats => AIcons.stats,
    };
  }
}

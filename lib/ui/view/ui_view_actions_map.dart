import 'package:flutter_media_view/ui/theme/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraMapActionView on MapAction {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      .selectStyle => l10n.mapStyleTooltip,
      .openMapApp => l10n.entryActionOpenMap,
      .zoomIn => l10n.mapZoomInTooltip,
      .zoomOut => l10n.mapZoomOutTooltip,
      .addShortcut => l10n.collectionActionAddShortcut,
      .toggleItemTrack =>
        // different data depending on toggle state
        l10n.mapShowItemTracks,
    };
  }

  Widget getIcon() => Icon(_getIconData());

  IconData _getIconData() {
    return switch (this) {
      .selectStyle => AIcons.layers,
      .openMapApp => AIcons.openOutside,
      .zoomIn => AIcons.zoomIn,
      .zoomOut => AIcons.zoomOut,
      .addShortcut => AIcons.addShortcut,
      .toggleItemTrack =>
        // different data depending on toggle state
        AIcons.route,
    };
  }
}

import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraMapClusterActionView on MapClusterAction {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      .editLocation => l10n.entryInfoActionEditLocation,
      .removeLocation => l10n.entryInfoActionRemoveLocation,
    };
  }

  Widget getIcon() => Icon(_getIconData());

  IconData _getIconData() {
    return switch (this) {
      .editLocation => AIcons.edit,
      .removeLocation => AIcons.clear,
    };
  }
}

import 'package:flutter_media_view/theme/icons.dart';
import 'package:flutter_media_view/widgets/common/extensions/build_context.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraSlideshowActionView on SlideshowAction {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      .resume => l10n.slideshowActionResume,
      .showInCollection => l10n.slideshowActionShowInCollection,
      .cast => l10n.entryActionCast,
      .settings => l10n.viewerActionSettings,
    };
  }

  Widget getIcon() => Icon(_getIconData());

  IconData _getIconData() {
    return switch (this) {
      .resume => AIcons.play,
      .showInCollection => AIcons.allCollection,
      .cast => AIcons.cast,
      .settings => AIcons.settings,
    };
  }
}

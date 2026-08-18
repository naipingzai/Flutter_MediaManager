import 'package:flutter_media_view/function/entry/function_entry.dart';
import 'package:flutter_media_view/function/entry/function_entry_extensions_props.dart';
import 'package:flutter_media_view/function/settings/function_settings.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_format.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_text.dart';
import 'package:flutter_media_view/ui/viewer/ui_widgets_viewer_multipage_controller.dart';
import 'package:flutter_media_view/ui/viewer/ui_widgets_viewer_overlay_top_details.dart';
import 'package:decorated_icon/decorated_icon.dart';
import 'package:flutter/material.dart';

class OverlayDateRow extends StatelessWidget {
  final AvesEntry entry;
  final MultiPageController? multiPageController;

  const OverlayDateRow({
    super.key,
    required this.entry,
    required this.multiPageController,
  });

  @override
  Widget build(BuildContext context) {
    final locale = settings.avesLocale;
    final use24hour = MediaQuery.alwaysUse24HourFormatOf(context);

    final date = entry.bestDate;
    final dateText = date != null ? formatDateTime(date, locale, use24hour) : AText.valueNotAvailable;
    final resolutionText = entry.isSvg
        ? entry.aspectRatioText
        : entry.isSized
        ? entry.getResolutionText(locale)
        : '';

    return Row(
      children: [
        DecoratedIcon(AIcons.date, size: ViewerDetailOverlayContent.iconSize, shadows: ViewerDetailOverlayContent.shadows(context)),
        const SizedBox(width: ViewerDetailOverlayContent.iconPadding),
        Expanded(flex: 3, child: Text(dateText)),
        Expanded(flex: 2, child: Text(resolutionText)),
      ],
    );
  }
}

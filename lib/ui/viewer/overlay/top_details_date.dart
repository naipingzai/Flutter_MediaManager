import 'package:fmv/function/entry/entry.dart';
import 'package:fmv/function/entry/extensions_props.dart';
import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/ui/theme/format.dart';
import 'package:fmv/ui/theme/icons.dart';
import 'package:fmv/ui/theme/text.dart';
import 'package:fmv/ui/viewer/multipage_controller.dart';
import 'package:fmv/ui/viewer/overlay/top_details.dart';
import 'package:decorated_icon/decorated_icon.dart';
import 'package:flutter/material.dart';

class OverlayDateRow extends StatelessWidget {
  final FmvEntry entry;
  final MultiPageController? multiPageController;

  const OverlayDateRow({
    super.key,
    required this.entry,
    required this.multiPageController,
  });

  @override
  Widget build(BuildContext context) {
    final locale = settings.fmvLocale;
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

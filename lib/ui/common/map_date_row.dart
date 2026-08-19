import 'package:fmv/function/entry/entry.dart';
import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/ui/theme/format.dart';
import 'package:fmv/ui/theme/icons.dart';
import 'package:fmv/ui/theme/text.dart';
import 'package:fmv/ui/common/map_info_row.dart';
import 'package:flutter/material.dart';

class MapDateRow extends StatelessWidget {
  final FmvEntry? entry;

  const MapDateRow({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final use24hour = MediaQuery.alwaysUse24HourFormatOf(context);

    final date = entry?.bestDate;
    final dateText = date != null ? formatDateTime(date, settings.fmvLocale, use24hour) : AText.valueNotAvailable;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MapInfoRow.iconPadding),
              child: Icon(AIcons.date, size: MapInfoRow.getIconSize(context)),
            ),
            alignment: PlaceholderAlignment.middle,
          ),
          TextSpan(text: dateText),
        ],
      ),
      softWrap: false,
      overflow: TextOverflow.fade,
      maxLines: 1,
    );
  }
}

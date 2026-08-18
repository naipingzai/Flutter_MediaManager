import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/theme/format.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/theme/text.dart';
import 'package:flutter_media_view/ui/common/map_info_row.dart';
import 'package:flutter/material.dart';

class MapDateRow extends StatelessWidget {
  final AvesEntry? entry;

  const MapDateRow({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final use24hour = MediaQuery.alwaysUse24HourFormatOf(context);

    final date = entry?.bestDate;
    final dateText = date != null ? formatDateTime(date, settings.avesLocale, use24hour) : AText.valueNotAvailable;
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

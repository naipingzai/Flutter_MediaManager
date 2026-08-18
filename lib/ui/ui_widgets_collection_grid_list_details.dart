import 'package:flutter_media_view/function/function_entry.dart';
import 'package:flutter_media_view/function/function_entry_extensions_location.dart';
import 'package:flutter_media_view/function/function_settings_enums_coordinate_format.dart';
import 'package:flutter_media_view/function/function_settings.dart';
import 'package:flutter_media_view/ui/ui_theme_format.dart';
import 'package:flutter_media_view/ui/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/ui_theme_text.dart';
import 'package:flutter_media_view/function/function_file_utils.dart';
import 'package:flutter_media_view/ui/ui_widgets_collection_grid_list_details_theme.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_fx_borders.dart';
import 'package:flutter_media_view_utils/flutter_media_view_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EntryListDetails extends StatelessWidget {
  final AvesEntry entry;

  const EntryListDetails({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final detailsTheme = context.watch<EntryListDetailsThemeData>();

    return Container(
      padding: EntryListDetailsTheme.contentPadding,
      foregroundDecoration: BoxDecoration(
        border: Border(top: AvesBorder.straightSide(context)),
      ),
      margin: EntryListDetailsTheme.contentMargin,
      child: IconTheme.merge(
        data: detailsTheme.iconTheme,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            Text(
              entry.bestTitle ?? context.l10n.viewerInfoUnknown,
              style: detailsTheme.titleStyle,
              softWrap: false,
              overflow: detailsTheme.titleMaxLines == 1 ? TextOverflow.fade : TextOverflow.ellipsis,
              maxLines: detailsTheme.titleMaxLines,
            ),
            const SizedBox(height: EntryListDetailsTheme.titleDetailPadding),
            if (detailsTheme.showDate) _buildDateRow(context, detailsTheme.captionStyle),
            if (detailsTheme.showLocation && entry.hasGps) _buildLocationRow(context, detailsTheme.captionStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<InlineSpan> spans, TextStyle style) {
    return Text.rich(
      TextSpan(
        children: spans,
      ),
      style: style,
      softWrap: false,
      overflow: TextOverflow.fade,
    );
  }

  WidgetSpan _buildIconSpan(IconData icon, {EdgeInsetsDirectional padding = EdgeInsetsDirectional.zero}) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 8, bottom: 1) + padding,
        child: Icon(icon),
      ),
    );
  }

  Widget _buildDateRow(BuildContext context, TextStyle style) {
    final locale = settings.avesLocale;
    final use24hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final date = entry.bestDate;
    final dateText = date != null ? formatDateTime(date, locale, use24hour) : AText.valueNotAvailable;

    final size = entry.stackedEntries?.map((v) => v.sizeBytes).sum ?? entry.sizeBytes;
    final sizeText = size != null ? formatFileSize(locale, size) : AText.valueNotAvailable;

    return Wrap(
      spacing: 8,
      children: [
        _buildRow(
          [_buildIconSpan(AIcons.date), TextSpan(text: dateText)],
          style,
        ),
        _buildRow(
          [_buildIconSpan(AIcons.size), TextSpan(text: sizeText)],
          style,
        ),
      ],
    );
  }

  Widget _buildLocationRow(BuildContext context, TextStyle style) {
    final location = entry.hasAddress ? entry.shortAddress : settings.coordinateFormat.format(context, entry.latLng!);

    return _buildRow(
      [_buildIconSpan(AIcons.location), TextSpan(text: location)],
      style,
    );
  }
}

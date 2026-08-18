import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/filters/container_dynamic_album.dart';
import 'package:flutter_media_view/function/filters/container_group_base.dart';
import 'package:flutter_media_view/function/filters/covered_stored_album.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_source.dart';
import 'package:flutter_media_view/ui/theme/format.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/theme/text.dart';
import 'package:flutter_media_view/function/utils/android_file_utils.dart';
import 'package:flutter_media_view/function/utils/file_utils.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/common_fx_borders.dart';
import 'package:flutter_media_view/ui/filter/widgets_filter_grids_common_list_details_theme.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FilterListDetails<T extends CollectionFilter> extends StatelessWidget {
  final FilterGridItem<T> gridItem;
  final bool pinned, locked;

  T get filter => gridItem.filter;

  FmvEntry? get entry => gridItem.entry;

  const FilterListDetails({
    super.key,
    required this.gridItem,
    required this.pinned,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    final detailsTheme = context.watch<FilterListDetailsThemeData>();

    final leading = filter.iconBuilder(context, detailsTheme.titleIconSize, allowGenericIcon: false);
    final hasTitleLeading = leading != null;

    return Container(
      padding: FilterListDetailsTheme.contentPadding,
      foregroundDecoration: BoxDecoration(
        border: Border(top: FmvBorder.straightSide(context)),
      ),
      margin: FilterListDetailsTheme.contentMargin,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                if (hasTitleLeading)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: FilterListDetailsTheme.titleIconPadding),
                      child: IconTheme(
                        data: IconThemeData(color: detailsTheme.titleStyle.color),
                        child: leading,
                      ),
                    ),
                  ),
                TextSpan(
                  text: filter.getLabel(context),
                  style: detailsTheme.titleStyle,
                ),
              ],
            ),
            softWrap: false,
            overflow: detailsTheme.titleMaxLines == 1 ? TextOverflow.fade : TextOverflow.ellipsis,
            maxLines: detailsTheme.titleMaxLines,
            // `textScaler` is applied to font size and icon size at the theme level,
            // otherwise the leading icon will be low-res scaled up/down
            textScaler: TextScaler.noScaling,
          ),
          if (!locked) ...[
            const SizedBox(height: FilterListDetailsTheme.titleDetailPadding),
            if (detailsTheme.showDate) _buildDateRow(context, detailsTheme, hasTitleLeading),
            if (detailsTheme.showCount) _buildCountRow(context, detailsTheme, hasTitleLeading),
          ],
        ],
      ),
    );
  }

  Widget _buildDateRow(BuildContext context, FilterListDetailsThemeData detailsTheme, bool hasTitleLeading) {
    final use24hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final date = entry?.bestDate;
    final dateText = date != null ? formatDateTime(date, settings.fmvLocale, use24hour) : AText.valueNotAvailable;

    Widget leading = const Icon(AIcons.date);
    if (hasTitleLeading) {
      leading = ConstrainedBox(
        constraints: BoxConstraints(minWidth: detailsTheme.titleIconSize),
        child: leading,
      );
    }
    return IconTheme.merge(
      data: detailsTheme.captionIconTheme,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dateText,
              style: detailsTheme.captionStyle,
              softWrap: false,
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountRow(BuildContext context, FilterListDetailsThemeData detailsTheme, bool hasTitleLeading) {
    final _filter = filter;
    final removableStorage = _filter is StoredAlbumFilter && androidFileUtils.isOnRemovableStorage(_filter.album);

    List<Widget> leadingIcons = [
      if (pinned) const Icon(AIcons.pin),
      if (removableStorage) const Icon(AIcons.storageCard),
      if (_filter is DynamicAlbumFilter) const Icon(AIcons.dynamicAlbum),
      if (_filter is GroupBaseFilter) const Icon(AIcons.group),
    ];

    Widget? leading;
    if (leadingIcons.isNotEmpty) {
      leading = Row(
        children: leadingIcons
            .mapIndexed(
              (i, child) => i > 0
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: child,
                    )
                  : child,
            )
            .toList(),
      );
    }

    leading = ConstrainedBox(
      constraints: BoxConstraints(minWidth: hasTitleLeading ? detailsTheme.titleIconSize : detailsTheme.captionIconTheme.size!),
      child: Center(child: leading ?? const SizedBox()),
    );

    final source = context.read<CollectionSource>();

    return IconTheme.merge(
      data: detailsTheme.captionIconTheme,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 8),
          Text(
            '${context.l10n.itemCount(source.count(filter))} • ${formatFileSize(settings.fmvLocale, source.size(filter))}',
            style: detailsTheme.captionStyle,
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
        ],
      ),
    );
  }
}

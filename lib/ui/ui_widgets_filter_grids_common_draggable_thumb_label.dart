import 'package:flutter_media_view/function/function_filters.dart';
import 'package:flutter_media_view/function/function_settings.dart';
import 'package:flutter_media_view/function/function_source_collection_source.dart';
import 'package:flutter_media_view/function/function_file_utils.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_grid_draggable_thumb_label.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FilterDraggableThumbLabel<T extends CollectionFilter> extends StatelessWidget {
  final ChipSortFactor sortFactor;
  final double offsetY;

  const FilterDraggableThumbLabel({
    super.key,
    required this.sortFactor,
    required this.offsetY,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableThumbLabel<FilterGridItem<T>>(
      offsetY: offsetY,
      lineBuilder: (context, filterGridItem) {
        switch (sortFactor) {
          case .date:
            return [
              DraggableThumbLabel.formatMonthThumbLabel(context, settings.avesLocale, filterGridItem.entry?.bestDate),
            ];
          case .name:
          case .path:
            return [
              filterGridItem.filter.getLabel(context),
            ];
          case .count:
            return [
              context.l10n.itemCount(context.read<CollectionSource>().count(filterGridItem.filter)),
            ];
          case .size:
            return [
              formatFileSize(settings.avesLocale, context.read<CollectionSource>().size(filterGridItem.filter)),
            ];
        }
      },
    );
  }
}

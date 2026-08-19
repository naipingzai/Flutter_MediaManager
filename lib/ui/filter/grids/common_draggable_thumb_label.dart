import 'package:fmv/function/filters/filters.dart';
import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/function/source/collection_source.dart';
import 'package:fmv/function/utils/file_utils.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv/ui/common/grid_draggable_thumb_label.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
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
              DraggableThumbLabel.formatMonthThumbLabel(context, settings.fmvLocale, filterGridItem.entry?.bestDate),
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
              formatFileSize(settings.fmvLocale, context.read<CollectionSource>().size(filterGridItem.filter)),
            ];
        }
      },
    );
  }
}

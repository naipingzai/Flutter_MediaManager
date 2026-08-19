import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/ui/common/grid_overlay.dart';
import 'package:flutter_media_view/ui/filter/grids/common_covered_filter_chip.dart';
import 'package:flutter_media_view/ui/filter/grids/common_overlay.dart';
import 'package:flutter/widgets.dart';

class FilterChipGridDecorator<T extends CollectionFilter, U extends FilterGridItem<T>> extends StatelessWidget {
  final U gridItem;
  final double extent;
  final bool selectable, highlightable;
  final Widget child;

  const FilterChipGridDecorator({
    super.key,
    required this.gridItem,
    required this.extent,
    this.selectable = true,
    this.highlightable = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.all(CoveredFilterChip.radius(extent));
    return SizedBox(
      width: extent,
      height: extent,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          if (selectable)
            GridItemSelectionOverlay<FilterGridItem<T>>(
              item: gridItem,
              borderRadius: borderRadius,
              padding: EdgeInsets.all(extent / 24),
            ),
          if (highlightable)
            ChipHighlightOverlay(
              filter: gridItem.filter,
              extent: extent,
              borderRadius: borderRadius,
            ),
        ],
      ),
    );
  }
}

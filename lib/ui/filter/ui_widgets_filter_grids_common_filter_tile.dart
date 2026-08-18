import 'package:flutter_media_view/function/filters/function_filters_covered_stored_album.dart';
import 'package:flutter_media_view/function/filters/function_filters.dart';
import 'package:flutter_media_view/function/settings/function_settings.dart';
import 'package:flutter_media_view/function/function_vaults.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_grid_scaling.dart';
import 'package:flutter_media_view/ui/filter/ui_widgets_common_identity_aves_filter_chip.dart';
import 'package:flutter_media_view/ui/filter/ui_widgets_filter_grids_common_covered_filter_chip.dart';
import 'package:flutter_media_view/ui/filter/ui_widgets_filter_grids_common_filter_chip_grid_decorator.dart';
import 'package:flutter_media_view/ui/filter/ui_widgets_filter_grids_common_list_details.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

typedef FilterTileTapCallback<T extends CollectionFilter> = void Function(FilterGridItem<T> gridItem, void Function(Route route) navigate);

class InteractiveFilterTile<T extends CollectionFilter> extends StatefulWidget {
  final FilterGridItem<T> gridItem;
  final double chipExtent, thumbnailExtent;
  final TileLayout tileLayout;
  final String? banner;
  final HeroType heroType;
  final FilterTileTapCallback<T> onTap;

  const InteractiveFilterTile({
    super.key,
    required this.gridItem,
    required this.chipExtent,
    required this.thumbnailExtent,
    required this.tileLayout,
    this.banner,
    required this.heroType,
    required this.onTap,
  });

  @override
  State<InteractiveFilterTile<T>> createState() => _InteractiveFilterTileState<T>();
}

class _InteractiveFilterTileState<T extends CollectionFilter> extends State<InteractiveFilterTile<T>> {
  HeroType? _heroTypeOverride;

  FilterGridItem<T> get gridItem => widget.gridItem;

  HeroType get effectiveHeroType => _heroTypeOverride ?? widget.heroType;

  @override
  Widget build(BuildContext context) {
    return MetaData(
      metaData: ScalerMetadata(gridItem),
      child: FilterTile(
        gridItem: gridItem,
        chipExtent: widget.chipExtent,
        thumbnailExtent: widget.thumbnailExtent,
        tileLayout: widget.tileLayout,
        banner: widget.banner,
        selectable: true,
        highlightable: true,
        onTap: (_) => widget.onTap(gridItem, _navigate),
        heroType: effectiveHeroType,
      ),
    );
  }

  void _navigate(Route route) {
    void _doNavigate() => Navigator.maybeOf(context)?.push(route);
    if (effectiveHeroType == HeroType.onTap) {
      // make sure the chip hero triggers, even when tapping on the list view details
      setState(() => _heroTypeOverride = HeroType.always);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _doNavigate();
      });
    } else {
      _doNavigate();
    }
  }
}

class FilterTile<T extends CollectionFilter> extends StatelessWidget {
  final FilterGridItem<T> gridItem;
  final double chipExtent, thumbnailExtent;
  final TileLayout tileLayout;
  final String? banner;
  final bool selectable, highlightable;
  final AFilterCallback? onTap;
  final HeroType heroType;

  const FilterTile({
    super.key,
    required this.gridItem,
    required this.chipExtent,
    required this.thumbnailExtent,
    required this.tileLayout,
    this.banner,
    this.selectable = false,
    this.highlightable = false,
    this.onTap,
    this.heroType = HeroType.never,
  });

  @override
  Widget build(BuildContext context) {
    final filter = gridItem.filter;
    final pinned = settings.pinnedFilters.contains(filter);
    final locked = filter is StoredAlbumFilter && vaults.isLocked(filter.album);
    final _onTap = onTap;

    switch (tileLayout) {
      case .mosaic:
      case .grid:
        return FilterChipGridDecorator<T, FilterGridItem<T>>(
          gridItem: gridItem,
          extent: chipExtent,
          selectable: selectable,
          highlightable: highlightable,
          child: CoveredFilterChip(
            filter: filter,
            extent: chipExtent,
            thumbnailExtent: thumbnailExtent,
            showText: true,
            pinned: pinned,
            locked: locked,
            banner: banner,
            onTap: _onTap,
            heroType: heroType,
          ),
        );
      case .list:
        Widget child = Row(
          crossAxisAlignment: .stretch,
          children: [
            FilterChipGridDecorator<T, FilterGridItem<T>>(
              gridItem: gridItem,
              extent: chipExtent,
              selectable: selectable,
              highlightable: highlightable,
              child: CoveredFilterChip(
                filter: filter,
                extent: chipExtent,
                thumbnailExtent: thumbnailExtent,
                showText: false,
                locked: locked,
                banner: banner,
                onTap: _onTap,
                heroType: heroType,
              ),
            ),
            Expanded(
              child: FilterListDetails(
                gridItem: gridItem,
                pinned: pinned,
                locked: locked,
              ),
            ),
          ],
        );
        if (_onTap != null) {
          // larger than the chip corner radius, so ink effects will be effectively clipped from the leading chip corners
          const radius = Radius.circular(123);
          child = InkWell(
            // as of Flutter v2.8.1, `InkWell` does not use `BorderRadiusGeometry`
            borderRadius: context.isRtl ? const BorderRadius.only(topRight: radius, bottomRight: radius) : const BorderRadius.only(topLeft: radius, bottomLeft: radius),
            onTap: () => _onTap(filter),
            child: child,
          );
        }
        return child;
    }
  }
}

import 'package:flutter_media_view/function/function_source_section_keys.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_grid_sections_fixed_section_layout_builder.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_grid_sections_list_layout.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_grid_sections_mosaic_section_layout_builder.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_grid_sections_section_layout_builder.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

typedef CoverRatioResolver<T> = double Function(T item);

abstract class SectionedListLayoutProvider<T> extends StatelessWidget {
  final double scrollableWidth;
  final TileLayout tileLayout;
  final int columnCount;
  final double spacing, horizontalPadding, tileWidth, tileHeight;
  final TileBuilder<T> tileBuilder;
  final Duration tileAnimationDelay;
  final CoverRatioResolver<T> coverRatioResolver;
  final Widget child;

  const SectionedListLayoutProvider({
    super.key,
    required this.scrollableWidth,
    required this.tileLayout,
    required int columnCount,
    required this.spacing,
    required this.horizontalPadding,
    required double tileWidth,
    required this.tileHeight,
    required this.tileBuilder,
    required this.tileAnimationDelay,
    required this.coverRatioResolver,
    required this.child,
  }) : assert(scrollableWidth != 0),
       columnCount = tileLayout == TileLayout.list ? 1 : columnCount,
       tileWidth = tileLayout == TileLayout.list ? scrollableWidth - (horizontalPadding * 2) : tileWidth;

  @override
  Widget build(BuildContext context) {
    return ProxyProvider0<SectionedListLayout<T>>(
      update: (context, _) {
        switch (tileLayout) {
          case .mosaic:
            return MosaicSectionLayoutBuilder<T>(
              sections: sections,
              showHeaders: showHeaders,
              getHeaderExtent: getHeaderExtent,
              buildHeader: buildHeader,
              scrollableWidth: scrollableWidth,
              tileLayout: tileLayout,
              columnCount: columnCount,
              spacing: spacing,
              horizontalPadding: horizontalPadding,
              tileWidth: tileWidth,
              tileHeight: tileHeight,
              tileBuilder: tileBuilder,
              tileAnimationDelay: tileAnimationDelay,
              coverRatioResolver: coverRatioResolver,
            ).updateLayouts(context);
          case .grid:
          case .list:
            return FixedExtentSectionLayoutBuilder<T>(
              sections: sections,
              showHeaders: showHeaders,
              buildHeader: buildHeader,
              getHeaderExtent: getHeaderExtent,
              scrollableWidth: scrollableWidth,
              tileLayout: tileLayout,
              columnCount: columnCount,
              spacing: spacing,
              horizontalPadding: horizontalPadding,
              tileWidth: tileWidth,
              tileHeight: tileHeight,
              tileBuilder: tileBuilder,
              tileAnimationDelay: tileAnimationDelay,
            ).updateLayouts(context);
        }
      },
      child: child,
    );
  }

  bool get showHeaders;

  Map<SectionKey, List<T>> get sections;

  double getHeaderExtent(BuildContext context, SectionKey sectionKey);

  Widget buildHeader(BuildContext context, SectionKey sectionKey, double headerExtent);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('scrollableWidth', scrollableWidth));
    properties.add(EnumProperty<TileLayout>('tileLayout', tileLayout));
    properties.add(IntProperty('columnCount', columnCount));
    properties.add(DoubleProperty('spacing', spacing));
    properties.add(DoubleProperty('horizontalPadding', horizontalPadding));
    properties.add(DoubleProperty('tileWidth', tileWidth));
    properties.add(DoubleProperty('tileHeight', tileHeight));
    properties.add(DiagnosticsProperty<bool>('showHeaders', showHeaders));
  }
}

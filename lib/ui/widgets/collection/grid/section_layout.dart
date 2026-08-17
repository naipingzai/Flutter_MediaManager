import 'package:flutter_media_view/function/function_entry.dart';
import 'package:flutter_media_view/function/function_source_collection_lens.dart';
import 'package:flutter_media_view/function/function_source_section_keys.dart';
import 'package:flutter_media_view/ui/widgets/collection/grid/headers/any.dart';
import 'package:flutter_media_view/ui/widgets/common/grid/sections/provider.dart';
import 'package:flutter/material.dart';

class SectionedEntryListLayoutProvider extends SectionedListLayoutProvider<AvesEntry> {
  final CollectionLens collection;
  final bool selectable;

  SectionedEntryListLayoutProvider({
    super.key,
    required this.collection,
    required this.selectable,
    required super.scrollableWidth,
    required super.tileLayout,
    required super.columnCount,
    required super.spacing,
    required super.horizontalPadding,
    required double tileExtent,
    required super.tileBuilder,
    required super.tileAnimationDelay,
    required super.child,
  }) : super(
         tileWidth: tileExtent,
         tileHeight: tileExtent,
         coverRatioResolver: (item) => item.displayAspectRatio,
       );

  @override
  bool get showHeaders => collection.showHeaders;

  @override
  Map<SectionKey, List<AvesEntry>> get sections => collection.sections;

  @override
  double getHeaderExtent(BuildContext context, SectionKey sectionKey) {
    return CollectionSectionHeader.getPreferredHeight(context, scrollableWidth, collection.source, sectionKey);
  }

  @override
  Widget buildHeader(BuildContext context, SectionKey sectionKey, double headerExtent) {
    return CollectionSectionHeader(
      collection: collection,
      sectionKey: sectionKey,
      height: headerExtent,
      selectable: selectable,
    );
  }
}

import 'package:flutter_media_view/function/function_filters_rating.dart';
import 'package:flutter_media_view/function/function_source_section_keys.dart';
import 'package:flutter_media_view/ui/widgets/common/grid/header.dart';
import 'package:flutter/material.dart';

class RatingSectionHeader<T> extends StatelessWidget {
  final int rating;
  final bool selectable;

  const RatingSectionHeader({
    super.key,
    required this.rating,
    required this.selectable,
  });

  @override
  Widget build(BuildContext context) {
    return SectionHeader<T>(
      sectionKey: EntryRatingSectionKey(rating),
      title: RatingFilter.formatRating(context, rating),
      selectable: selectable,
    );
  }
}

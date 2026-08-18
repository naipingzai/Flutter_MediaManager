import 'package:flutter_media_view/function/filters/rating.dart';
import 'package:flutter_media_view/function/source/section_keys.dart';
import 'package:flutter_media_view/ui/common/common_grid_header.dart';
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

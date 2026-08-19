import 'dart:math';

import 'package:fmv/function/entry/entry.dart';
import 'package:fmv/function/source/collection_lens.dart';
import 'package:fmv/function/source/collection_source.dart';
import 'package:fmv/function/source/section_keys.dart';
import 'package:fmv/function/calendar/utils.dart';
import 'package:fmv/ui/collection/grid_headers_album.dart';
import 'package:fmv/ui/collection/grid_headers_date.dart';
import 'package:fmv/ui/collection/grid_headers_rating.dart';
import 'package:fmv/ui/common/grid_header.dart';
import 'package:flutter/material.dart';

class CollectionSectionHeader extends StatelessWidget {
  final CollectionLens collection;
  final SectionKey sectionKey;
  final double height;
  final bool selectable;

  const CollectionSectionHeader({
    super.key,
    required this.collection,
    required this.sectionKey,
    required this.height,
    required this.selectable,
  });

  @override
  Widget build(BuildContext context) {
    final header = _buildHeader(context);
    return header != null
        ? SizedBox(
            height: height,
            child: header,
          )
        : const SizedBox();
  }

  Widget? _buildHeader(BuildContext context) {
    switch (collection.sortFactor) {
      case .date:
        switch (collection.sectionFactor) {
          case .album:
            return _buildAlbumHeader(context);
          case .month:
            var k = sectionKey as EntryDateSectionKey;
            final date = collection.calendar.ops.fromYearMonthDay(k.year, k.month, k.day);
            return MonthSectionHeader<FmvEntry>(
              key: ValueKey(sectionKey),
              sectionKey: sectionKey,
              date: date,
              selectable: selectable,
            );
          case .day:
            var k = sectionKey as EntryDateSectionKey;
            final date = collection.calendar.ops.fromYearMonthDay(k.year, k.month, k.day);
            return DaySectionHeader<FmvEntry>(
              key: ValueKey(sectionKey),
              sectionKey: sectionKey,
              date: date,
              selectable: selectable,
            );
          case .none:
            break;
        }
      case .name:
      case .path:
        return _buildAlbumHeader(context);
      case .rating:
        return RatingSectionHeader<FmvEntry>(
          key: ValueKey(sectionKey),
          rating: (sectionKey as EntryRatingSectionKey).rating,
          selectable: selectable,
        );
      case .size:
      case .duration:
        break;
    }
    return null;
  }

  Widget _buildAlbumHeader(BuildContext context) {
    final source = collection.source;
    final directory = (sectionKey as EntryAlbumSectionKey).directory;
    return AlbumSectionHeader(
      key: ValueKey(sectionKey),
      directory: directory,
      albumName: directory != null ? source.getStoredAlbumDisplayName(context, directory) : null,
      selectable: selectable,
    );
  }

  static double getPreferredHeight(BuildContext context, double maxWidth, CollectionSource source, SectionKey sectionKey) {
    var headerExtent = 0.0;
    if (sectionKey is EntryAlbumSectionKey) {
      // only compute height for album headers, as they're the only likely ones to split on multiple lines
      headerExtent = AlbumSectionHeader.getPreferredHeight(context, maxWidth, source, sectionKey);
    }

    final textScaler = MediaQuery.textScalerOf(context);
    headerExtent = max(headerExtent, textScaler.scale(SectionHeader.leadingSize.height)) + SectionHeader.padding.vertical + SectionHeader.margin.vertical;
    return headerExtent;
  }
}

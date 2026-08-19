import 'package:fmv/function/entry/entry.dart';
import 'package:fmv/function/filters/rating.dart';
import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/function/source/collection_lens.dart';
import 'package:fmv/function/source/collection_source.dart';
import 'package:fmv/function/utils/file_utils.dart';
import 'package:fmv/ui/common/grid_draggable_thumb_label.dart';
import 'package:fmv/ui/common/grid_sections_list_layout.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CollectionDraggableThumbLabel extends StatelessWidget {
  final CollectionLens collection;
  final double offsetY;

  const CollectionDraggableThumbLabel({
    super.key,
    required this.collection,
    required this.offsetY,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableThumbLabel<FmvEntry>(
      offsetY: offsetY,
      lineBuilder: (context, entry) {
        switch (collection.sortFactor) {
          case .date:
            final locale = settings.fmvLocale;
            final date = entry.bestDate;
            switch (collection.sectionFactor) {
              case .album:
                return [
                  DraggableThumbLabel.formatMonthThumbLabel(context, locale, date),
                  if (_showAlbumName(context, entry)) _getAlbumName(context, entry),
                ];
              case .month:
              case .none:
                return [
                  DraggableThumbLabel.formatMonthThumbLabel(context, locale, date),
                ];
              case .day:
                return [
                  DraggableThumbLabel.formatDayThumbLabel(context, locale, date),
                ];
            }
          case .name:
            return [
              if (_showAlbumName(context, entry)) _getAlbumName(context, entry),
              ?entry.bestTitle,
            ];
          case .rating:
            final locale = settings.fmvLocale;
            final date = entry.bestDate;
            return [
              RatingFilter.formatRating(context, entry.rating),
              DraggableThumbLabel.formatMonthThumbLabel(context, locale, date),
            ];
          case .size:
            final locale = settings.fmvLocale;
            final sizeBytes = entry.sizeBytes;
            return [
              if (sizeBytes != null) formatFileSize(locale, sizeBytes, round: 0),
            ];
          case .duration:
            return [
              if (entry.durationMillis != null) entry.durationText,
            ];
          case .path:
            final entryFilename = entry.filenameWithoutExtension;
            return [
              if (_showAlbumName(context, entry)) _getAlbumName(context, entry),
              ?entryFilename,
            ];
        }
      },
    );
  }

  bool _hasMultipleSections(BuildContext context) => context.read<SectionedListLayout<FmvEntry>>().sections.length > 1;

  bool _showAlbumName(BuildContext context, FmvEntry entry) => _hasMultipleSections(context) && entry.directory != null;

  String _getAlbumName(BuildContext context, FmvEntry entry) => context.read<CollectionSource>().getStoredAlbumDisplayName(context, entry.directory!);
}

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/media/multipage.dart';
import 'package:flutter_media_view/ui/theme/text.dart';
import 'package:flutter_media_view/ui/viewer/multipage_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class OverlayPositionTitleRow extends StatelessWidget {
  final FmvEntry entry;
  final String? collectionPosition;
  final MultiPageController? multiPageController;

  const OverlayPositionTitleRow({
    super.key,
    required this.entry,
    required this.collectionPosition,
    required this.multiPageController,
  });

  @override
  Widget build(BuildContext context) {
    final _title = entry.bestTitle;

    Text toText({String? pagePosition}) => Text(
      [
        if (collectionPosition != null) collectionPosition,
        ?pagePosition,
        if (_title != null) '${Unicode.FSI}$_title${Unicode.PDI}',
      ].join(AText.separator),
    );

    if (multiPageController == null) return toText();

    return StreamBuilder<MultiPageInfo?>(
      stream: multiPageController!.infoStream,
      builder: (context, snapshot) {
        final multiPageInfo = multiPageController!.info;
        String? pagePosition;
        if (multiPageInfo != null) {
          // page count may be 0 when we know an entry to have multiple pages
          // but fail to get information about these pages
          final pageCount = multiPageInfo.pageCount;
          if (pageCount > 0) {
            final page = multiPageInfo.getById(entry.pageId ?? entry.id) ?? multiPageInfo.defaultPage;
            pagePosition = '${(page?.index ?? 0) + 1}/$pageCount';
          }
        }
        return toText(pagePosition: pagePosition);
      },
    );
  }
}

import 'dart:async';

import 'package:fmv/function/filters/covered_stored_album.dart';
import 'package:fmv/function/filters/filters.dart';
import 'package:fmv/function/source/collection_source.dart';
import 'package:fmv/ui/common/actions/common_controls_quick_common_menu.dart';
import 'package:fmv/ui/filter/common_controls_quick_quick_chooser_mixin.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AlbumQuickChooser extends StatelessWidget with FilterQuickChooserMixin<String> {
  final ValueNotifier<String?> valueNotifier;
  @override
  final List<String> options;
  final bool blurred;
  final PopupMenuPosition chooserPosition;
  final Stream<Offset> pointerGlobalPosition;

  const AlbumQuickChooser({
    super.key,
    required this.valueNotifier,
    required this.options,
    required this.blurred,
    required this.chooserPosition,
    required this.pointerGlobalPosition,
  });

  @override
  Widget build(BuildContext context) {
    return MenuQuickChooser<String>(
      valueNotifier: valueNotifier,
      options: options,
      autoReverse: true,
      blurred: blurred,
      chooserPosition: chooserPosition,
      pointerGlobalPosition: pointerGlobalPosition,
      maxTotalOptionCount: FilterQuickChooserMixin.maxTotalOptionCount,
      itemHeight: computeItemHeight(context),
      contentWidth: computeLargestItemWidth,
      itemBuilder: itemBuilder,
      emptyBuilder: (context) => Text(context.l10n.albumEmpty),
    );
  }

  @override
  CollectionFilter buildFilter(BuildContext context, String option) {
    final source = context.read<CollectionSource>();
    return StoredAlbumFilter(option, source.getStoredAlbumDisplayName(context, option));
  }
}

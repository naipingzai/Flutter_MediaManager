import 'dart:async';

import 'package:flutter_media_view/function/filters/function_filters_covered_stored_album.dart';
import 'package:flutter_media_view/function/filters/function_filters.dart';
import 'package:flutter_media_view/function/source/function_source_collection_source.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_action_controls_quick_choosers_common_menu.dart';
import 'package:flutter_media_view/ui/filter/ui_widgets_common_action_controls_quick_choosers_filter_quick_chooser_mixin.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
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

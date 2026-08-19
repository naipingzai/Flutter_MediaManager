import 'package:flutter_media_view/function/filters/covered_tag.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_source.dart';
import 'package:flutter_media_view/ui/common/view.dart';
import 'package:flutter_media_view/ui/common/actions/common_action_controls_quick_choosers_common_button.dart';
import 'package:flutter_media_view/ui/filter/common_action_controls_quick_choosers_quick_chooser_mixin.dart';
import 'package:flutter_media_view/ui/common/actions/common_action_controls_quick_choosers_tag_chooser.dart';
import 'package:flutter_media_view/ui/common/providers_media_query_data_provider.dart';
import 'package:flutter_media_view/ui/filter/grids/common_nav_page.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TagButton extends ChooserQuickButton<CollectionFilter> {
  const TagButton({
    super.key,
    required super.blurred,
    super.onChooserValue,
    super.focusNode,
    required super.onPressed,
  });

  @override
  State<TagButton> createState() => _TagButtonState();
}

class _TagButtonState extends ChooserQuickButtonState<TagButton, CollectionFilter> {
  EntryAction get action => EntryAction.editTags;

  @override
  Widget get icon => action.getIcon();

  @override
  String get tooltip => action.getText(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final source = context.read<CollectionSource?>();
      settings.removeObsoleteRecentTags(source);
    });
  }

  @override
  Widget buildChooser(Animation<double> animation, PopupMenuPosition chooserPosition) {
    final options = settings.recentTags;
    final takeCount = FilterQuickChooserMixin.maxTotalOptionCount - options.length;
    if (takeCount > 0) {
      final source = context.read<CollectionSource>();
      final filters = source.sortedTags.map(TagFilter.new).whereNot(options.contains).toSet();
      final allMapEntries = filters.map((filter) => FilterGridItem(filter, source.recentEntry(filter))).toList();
      allMapEntries.sort(FilterNavigationPage.compareFiltersByDate);
      options.addAll(allMapEntries.take(takeCount).map((v) => v.filter));
    }

    return MediaQueryDataProvider(
      child: FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation,
          alignment: chooserPosition == PopupMenuPosition.over ? Alignment.bottomCenter : Alignment.topCenter,
          child: TagQuickChooser(
            valueNotifier: chooserValueNotifier,
            options: options,
            blurred: widget.blurred,
            chooserPosition: chooserPosition,
            pointerGlobalPosition: pointerGlobalPosition,
          ),
        ),
      ),
    );
  }
}

import 'package:fmv/function/filters/filters.dart';
import 'package:fmv/function/model/function_selection.dart';
import 'package:fmv/ui/common/basic/basic_query_bar.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FilterQueryBar<T extends CollectionFilter> extends StatelessWidget {
  final ValueNotifier<String> queryNotifier;
  final FocusNode focusNode;

  const FilterQueryBar({
    super.key,
    required this.queryNotifier,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return Container(
      height: getPreferredHeight(textScaler),
      alignment: Alignment.topCenter,
      child: Selector<Selection<FilterGridItem<T>>, bool>(
        selector: (context, selection) => !selection.isSelecting,
        builder: (context, editable, child) => QueryBar(
          queryNotifier: queryNotifier,
          focusNode: focusNode,
          hintText: context.l10n.collectionSearchTitlesHintText,
          editable: editable,
        ),
      ),
    );
  }

  static double getPreferredHeight(TextScaler textScaler) => QueryBar.getPreferredHeight(textScaler);
}

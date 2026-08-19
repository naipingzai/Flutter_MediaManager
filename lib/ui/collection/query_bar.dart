import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/model/function_selection.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_query_bar.dart';
import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EntryQueryBar extends StatefulWidget {
  final ValueNotifier<String> queryNotifier;
  final FocusNode focusNode;

  const EntryQueryBar({
    super.key,
    required this.queryNotifier,
    required this.focusNode,
  });

  @override
  State<EntryQueryBar> createState() => _EntryQueryBarState();

  static double getPreferredHeight(TextScaler textScaler) => QueryBar.getPreferredHeight(textScaler);
}

class _EntryQueryBarState extends State<EntryQueryBar> {
  @override
  void initState() {
    super.initState();
    _registerWidget(widget);
  }

  @override
  void didUpdateWidget(covariant EntryQueryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
  }

  @override
  void dispose() {
    _unregisterWidget(widget);
    super.dispose();
  }

  void _registerWidget(EntryQueryBar widget) {
    widget.queryNotifier.addListener(_onQueryChanged);
  }

  void _unregisterWidget(EntryQueryBar widget) {
    widget.queryNotifier.removeListener(_onQueryChanged);
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return Container(
      height: EntryQueryBar.getPreferredHeight(textScaler),
      alignment: Alignment.topCenter,
      child: Selector<Selection<FmvEntry>, bool>(
        selector: (context, selection) => !selection.isSelecting,
        builder: (context, editable, child) => QueryBar(
          queryNotifier: widget.queryNotifier,
          focusNode: widget.focusNode,
          hintText: context.l10n.collectionSearchTitlesHintText,
          editable: editable,
        ),
      ),
    );
  }

  void _onQueryChanged() {
    final query = widget.queryNotifier.value;
    context.read<CollectionLens>().setLiveQuery(query);
  }
}

import 'package:fmv/function/entry/entry.dart';
import 'package:fmv/function/source/collection_lens.dart';
import 'package:fmv/ui/common/basic/basic_scaffold.dart';
import 'package:fmv/ui/common/extensions_theme.dart';
import 'package:fmv/ui/viewer/controls/controller.dart';
import 'package:fmv/ui/viewer/entry_viewer_stack.dart';
import 'package:fmv/ui/viewer/providers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EntryViewerPage extends StatefulWidget {
  static const routeName = '/viewer';

  // provided collection should be a new instance specifically created
  // for the `EntryViewerPage` widget, so it can be safely disposed here
  final CollectionLens? collection;
  final FmvEntry initialEntry;

  const EntryViewerPage({
    super.key,
    this.collection,
    required this.initialEntry,
  });

  @override
  State<EntryViewerPage> createState() => _EntryViewerPageState();

  static Color getBackground(BuildContext context) => Theme.of(context).isDark ? Colors.black : Colors.white;
}

class _EntryViewerPageState extends State<EntryViewerPage> {
  final ViewerController _viewerController = ViewerController();

  @override
  void dispose() {
    _viewerController.dispose();
    // provided collection should be a new instance specifically created
    // for the `EntryViewerPage` widget, so it can be safely disposed here
    widget.collection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    return FmvScaffold(
      body: MultiProvider(
        providers: [
          ViewStateConductorProvider(),
          VideoConductorProvider(collection: collection),
          MultiPageConductorProvider(),
        ],
        child: EntryViewerStack(
          collection: collection,
          initialEntry: widget.initialEntry,
          viewerController: _viewerController,
        ),
      ),
      backgroundColor: Navigator.canPop(context) ? Colors.transparent : EntryViewerPage.getBackground(context),
      resizeToAvoidBottomInset: false,
    );
  }
}

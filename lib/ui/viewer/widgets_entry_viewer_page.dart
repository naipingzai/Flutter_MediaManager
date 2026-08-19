import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/common/common_extensions_theme.dart';
import 'package:flutter_media_view/ui/viewer/widgets_controls_controller.dart';
import 'package:flutter_media_view/ui/viewer/widgets_entry_viewer_stack.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_providers.dart';
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

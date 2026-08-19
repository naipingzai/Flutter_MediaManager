import 'package:flutter_media_view/core/app_mode.dart';
import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/filters/covered_stored_album.dart';
import 'package:flutter_media_view/function/filters/mime.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/function/source/collection_source.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/collection/page.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/identity/common_identity_empty.dart';
import 'package:flutter_media_view/ui/viewer/settings/slideshow_page.dart';
import 'package:flutter_media_view/ui/viewer/controls/controller.dart';
import 'package:flutter_media_view/ui/viewer/entry_viewer_stack.dart';
import 'package:flutter_media_view/ui/viewer/providers.dart';
import 'package:fmv_magnifier/flutter_media_view_magnifier.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SlideshowPage extends StatefulWidget {
  static const routeName = '/collection/slideshow';

  final CollectionLens collection;

  const SlideshowPage({
    super.key,
    required this.collection,
  });

  @override
  State<SlideshowPage> createState() => _SlideshowPageState();
}

class _SlideshowPageState extends State<SlideshowPage> {
  final ValueNotifier<AppMode> _appModeNotifier = ValueNotifier(.slideshow);
  late ViewerController _viewerController;
  late CollectionLens _slideshowCollection;
  FmvEntry? _initialEntry;

  CollectionSource get source => widget.collection.source;

  @override
  void initState() {
    super.initState();
    _initViewerController(autopilot: true);
    _initSlideshowCollection();
    _initialEntry = _slideshowCollection.sortedEntries.firstOrNull;
  }

  @override
  void dispose() {
    _appModeNotifier.dispose();
    _disposeViewerController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialEntry = _initialEntry;
    return ListenableProvider<ValueNotifier<AppMode>>.value(
      value: _appModeNotifier,
      child: FmvScaffold(
        body: initialEntry == null
            ? EmptyContent(
                icon: AIcons.image,
                text: context.l10n.collectionEmptyImages,
                alignment: Alignment.center,
              )
            : MultiProvider(
                providers: [
                  ViewStateConductorProvider(),
                  VideoConductorProvider(),
                  MultiPageConductorProvider(),
                ],
                child: NotificationListener<SlideshowActionNotification>(
                  onNotification: (notification) {
                    _onActionSelected(notification.action);
                    return true;
                  },
                  child: EntryViewerStack(
                    key: ValueKey(_viewerController),
                    collection: _slideshowCollection,
                    initialEntry: initialEntry,
                    viewerController: _viewerController,
                  ),
                ),
              ),
      ),
    );
  }

  void _initViewerController({required bool autopilot}) {
    _viewerController = ViewerController(
      initialScale: ScaleLevel(ref: settings.slideshowFillScreen ? ScaleReference.covered : ScaleReference.contained),
      transition: settings.slideshowTransition,
      repeat: settings.slideshowRepeat,
      autopilot: autopilot,
      autopilotInterval: Duration(seconds: settings.slideshowInterval),
      autopilotAnimatedZoom: settings.slideshowAnimatedZoomEffect,
    );
  }

  void _disposeViewerController() => _viewerController.dispose();

  void _initSlideshowCollection() {
    var entries = List.of(widget.collection.sortedEntries);
    if (settings.slideshowVideoPlayback == SlideshowVideoPlayback.skip) {
      entries = entries.where((entry) => !MimeFilter.video.test(entry)).toList();
    }
    if (settings.slideshowShuffle) {
      entries.shuffle();
    }
    _slideshowCollection = CollectionLens(
      source: source,
      listenToSource: false,
      fixedSort: true,
      fixedSelection: entries,
    );
  }

  void _onActionSelected(SlideshowAction action) {
    switch (action) {
      case .resume:
        _viewerController.autopilot = true;
      case .showInCollection:
        _showInCollection();
      case .cast:
        // ignore, as it should be handled at the viewer level
        break;
      case .settings:
        _showSettings(context);
    }
  }

  void _showInCollection() {
    final currentEntry = _viewerController.entryNotifier.value;
    if (currentEntry == null) return;

    final album = currentEntry.directory;
    final uri = currentEntry.uri;

    Navigator.maybeOf(context)?.pushAndRemoveUntil(
      MaterialPageRoute(
        settings: const RouteSettings(name: CollectionPage.routeName),
        builder: (context) => CollectionPage(
          source: source,
          filters: album != null ? {StoredAlbumFilter(album, source.getStoredAlbumDisplayName(context, album))} : null,
          highlightTest: (entry) => entry.uri == uri,
        ),
      ),
      (route) => false,
    );
  }

  (bool, bool) get collectionSettings => (settings.slideshowShuffle, settings.slideshowVideoPlayback == SlideshowVideoPlayback.skip);

  Future<void> _showSettings(BuildContext context) async {
    final oldCollectionSettings = collectionSettings;
    final currentEntry = _viewerController.entryNotifier.value;

    await Navigator.maybeOf(context)?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: ViewerSlideshowPage.routeName),
        builder: (context) => const ViewerSlideshowPage(),
      ),
    );

    _disposeViewerController();
    _initViewerController(autopilot: false);
    if (oldCollectionSettings != collectionSettings) {
      _initSlideshowCollection();
    }
    final slideshowEntries = _slideshowCollection.sortedEntries;
    _initialEntry = slideshowEntries.contains(currentEntry) ? currentEntry : slideshowEntries.firstOrNull;
    setState(() {});
  }
}

class SlideshowActionNotification extends Notification {
  final SlideshowAction action;

  SlideshowActionNotification(this.action);
}

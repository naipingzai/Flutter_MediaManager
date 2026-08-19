import 'package:flutter_media_view/function/utils/function_uri.dart';
import 'package:flutter_media_view/function/device/function_device.dart';
import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/common/actions/mixins_feedback.dart';
import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/dialogs_add_shortcut_dialog.dart';
import 'package:flutter_media_view/ui/common/dialogs_fmv_dialog.dart';
import 'package:flutter_media_view/ui/common/dialogs_map_style_selection_dialog.dart';
import 'package:flutter_media_view/ui/common/map_page.dart';
import 'package:fmv_map/flutter_media_view_map.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MapActionDelegate with FeedbackMixin {
  final FmvMapController controller;

  const MapActionDelegate(this.controller);

  bool _isMapPage(BuildContext context) => context.currentRouteName == MapPage.routeName;

  bool isVisible(BuildContext context, MapAction action) {
    switch (action) {
      case .selectStyle:
      case .zoomIn:
      case .zoomOut:
        return true;
      case .openMapApp:
        return _isMapPage(context);
      case .addShortcut:
        return _isMapPage(context) && device.canPinShortcut;
      case .toggleItemTrack:
        return _isMapPage(context);
    }
  }

  void onActionSelected(BuildContext context, MapAction action) {
    switch (action) {
      case .selectStyle:
        selectStyle(context);
      case .openMapApp:
        OpenMapAppNotification().dispatch(context);
      case .zoomIn:
        controller.zoomBy(1);
      case .zoomOut:
        controller.zoomBy(-1);
      case .addShortcut:
        _addShortcut(context);
      case .toggleItemTrack:
        settings.mapShowItemTracks = !settings.mapShowItemTracks;
    }
  }

  static void selectStyle(BuildContext context) {
    Navigator.maybeOf(context)?.push<EntryMapStyle>(
      MaterialPageRoute(
        settings: const RouteSettings(name: MapStyleSelectionDialog.routeName),
        builder: (context) => const MapStyleSelectionDialog(),
      ),
    );
  }

  Future<void> _addShortcut(BuildContext context) async {
    final idleBounds = controller.idleBounds;
    if (idleBounds == null) {
      showFeedback(context, FeedbackType.warn, context.l10n.genericFailureFeedback);
      return;
    }

    final collection = context.read<CollectionLens>();
    final result = await showFmvDialog<(FmvEntry?, String)>(
      context: context,
      builder: (context) => AddShortcutDialog(
        defaultName: '',
        collection: collection,
      ),
      routeSettings: const RouteSettings(name: AddShortcutDialog.routeName),
    );
    if (result == null) return;

    final (coverEntry, name) = result;
    if (name.isEmpty) return;

    final geoUri = toGeoUri(idleBounds.projectedCenter, zoom: idleBounds.zoom);
    await appService.pinToHomeScreen(
      name,
      coverEntry,
      route: MapPage.routeName,
      filters: collection.filters,
      geoUri: geoUri,
    );
    if (!device.showPinShortcutFeedback) {
      showFeedback(context, FeedbackType.info, context.l10n.genericSuccessFeedback);
    }
  }
}

class OpenMapAppNotification extends Notification {}

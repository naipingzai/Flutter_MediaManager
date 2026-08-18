import 'package:flutter_media_view/app_mode.dart';
import 'package:flutter_media_view/function/function_device.dart';
import 'package:flutter_media_view/function/entry/function_entry.dart';
import 'package:flutter_media_view/function/filters/function_filters_path.dart';
import 'package:flutter_media_view/function/settings/function_settings.dart';
import 'package:flutter_media_view/function/source/function_source_collection_lens.dart';
import 'package:flutter_media_view/function/source/function_source_collection_source.dart';
import 'package:flutter_media_view/function/common/function_common_services.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_action_mixins_feedback.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_dialogs_add_shortcut_dialog.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_dialogs_aves_dialog.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_explorer_explorer_page.dart';
import 'package:flutter_media_view/ui/filter/ui_widgets_filter_grids_common_action_delegates_chip.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_stats_stats_page.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ExplorerActionDelegate with FeedbackMixin {
  final VolumeRelativeDirectory directory;

  ExplorerActionDelegate({required this.directory});

  bool isVisible(
    ExplorerAction action, {
    required AppMode appMode,
  }) {
    final isMain = appMode == .main;
    final useTvLayout = settings.useTvLayout;
    switch (action) {
      case .addShortcut:
        return isMain && device.canPinShortcut;
      case .setHome:
        return isMain && !useTvLayout;
      case .hide:
      case .stats:
        return isMain;
    }
  }

  bool canApply(ExplorerAction action) {
    switch (action) {
      case .addShortcut:
      case .setHome:
      case .hide:
      case .stats:
        return true;
    }
  }

  void onActionSelected(BuildContext context, ExplorerAction action) {
    reportService.log('$runtimeType handles $action');
    switch (action) {
      case .addShortcut:
        _addShortcut(context);
      case .setHome:
        _setHome(context);
      case .hide:
        _hide(context);
      case .stats:
        _goToStats(context);
    }
  }

  PathFilter _getPathFilter() => PathFilter(directory.dirPath);

  Future<void> _addShortcut(BuildContext context) async {
    final filter = _getPathFilter();
    final defaultName = filter.getLabel(context);
    final collection = CollectionLens(
      source: context.read<CollectionSource>(),
      filters: {filter},
    );

    final result = await showAvesDialog<(AvesEntry?, String)>(
      context: context,
      builder: (context) => AddShortcutDialog(
        defaultName: defaultName,
        collection: collection,
      ),
      routeSettings: const RouteSettings(name: AddShortcutDialog.routeName),
    );
    if (result == null) return;

    final (coverEntry, name) = result;
    if (name.isEmpty) return;

    await appService.pinToHomeScreen(name, coverEntry, route: ExplorerPage.routeName, path: filter.path);
    if (!device.showPinShortcutFeedback) {
      showFeedback(context, FeedbackType.info, context.l10n.genericSuccessFeedback);
    }
  }

  void _setHome(BuildContext context) async {
    settings.setHome(HomePageSetting.explorer, customExplorerPath: directory.dirPath);
    showFeedback(context, FeedbackType.info, context.l10n.genericSuccessFeedback);
  }

  void _hide(BuildContext context) {
    final chipActionDelegate = ChipActionDelegate();
    const action = ChipAction.hide;
    final pathFilter = _getPathFilter();
    if (chipActionDelegate.isVisible(action, filter: pathFilter)) {
      chipActionDelegate.onActionSelected(context, pathFilter, action);
    }
  }

  void _goToStats(BuildContext context) {
    final collection = CollectionLens(
      source: context.read<CollectionSource>(),
      filters: {_getPathFilter()},
    );

    Navigator.maybeOf(context)?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: StatsPage.routeName),
        builder: (context) => StatsPage(
          entries: collection.sortedEntries.toSet(),
          source: collection.source,
        ),
      ),
    );
  }
}

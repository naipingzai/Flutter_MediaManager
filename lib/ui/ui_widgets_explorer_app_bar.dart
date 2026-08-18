import 'dart:async';

import 'package:flutter_media_view/app_mode.dart';
import 'package:flutter_media_view/function/function_filters.dart';
import 'package:flutter_media_view/function/function_filters_path.dart';
import 'package:flutter_media_view/function/function_settings_enums_accessibility_animations.dart';
import 'package:flutter_media_view/function/function_settings.dart';
import 'package:flutter_media_view/function/function_source_collection_source.dart';
import 'package:flutter_media_view/function/function_common_services.dart';
import 'package:flutter_media_view/ui/ui_theme_icons.dart';
import 'package:flutter_media_view/function/function_android_file_utils.dart';
import 'package:flutter_media_view/ui/ui_view.dart';
import 'package:flutter_media_view/ui/ui_widgets_collection_collection_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_app_bar_app_bar_subtitle.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_app_bar_app_bar_title.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_app_bar_crumb_line.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_basic_font_size_icon_theme.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_basic_popup_menu_row.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_identity_aves_app_bar.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_identity_aves_filter_chip.dart';
import 'package:flutter_media_view/ui/ui_widgets_dialogs_aves_dialog.dart';
import 'package:flutter_media_view/ui/ui_widgets_dialogs_select_storage_dialog.dart';
import 'package:flutter_media_view/ui/ui_widgets_explorer_crumb_line.dart';
import 'package:flutter_media_view/ui/ui_widgets_explorer_explorer_action_delegate.dart';
import 'package:flutter_media_view/ui/ui_widgets_search_collection_search_page_route.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

class ExplorerAppBar extends StatefulWidget {
  final ValueNotifier<VolumeRelativeDirectory?> directoryNotifier;
  final void Function(VolumeRelativeDirectory? dir) goToDir;

  const ExplorerAppBar({
    super.key,
    required this.directoryNotifier,
    required this.goToDir,
  });

  @override
  State<ExplorerAppBar> createState() => _ExplorerAppBarState();
}

class _ExplorerAppBarState extends State<ExplorerAppBar> with WidgetsBindingObserver {
  Set<StorageVolume> get _volumes => androidFileUtils.storageVolumes;

  String? _pathOf(VolumeRelativeDirectory? dir) => dir != null ? pContext.join(dir.volumePath, dir.relativeDir) : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AvesAppBar(
      contentHeight: appBarContentHeight,
      pinned: false,
      leading: const DrawerButton(),
      title: _buildAppBarTitle(context),
      actions: _buildActions,
      bottom: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            padding: CrumbLine.padding,
            width: constraints.maxWidth,
            height: CrumbLine.getPreferredHeight(MediaQuery.textScalerOf(context)),
            child: ValueListenableBuilder<VolumeRelativeDirectory?>(
              valueListenable: widget.directoryNotifier,
              builder: (context, contentsDirectory, child) {
                WidgetBuilder? lastCrumbBuilder;
                final canNavigate = context.select<ValueNotifier<AppMode>, bool>((v) => v.value.canNavigate);
                if (canNavigate) {
                  final dirPath = _pathOf(contentsDirectory);
                  if (dirPath != null) {
                    lastCrumbBuilder = (context) => AvesFilterChip(
                      filter: PathFilter(dirPath),
                      onTap: (filter) => _goToCollectionPage(context, filter),
                      onLongPress: null,
                    );
                  }
                }
                return ExplorerCrumbLine(
                  key: const Key('crumbs'),
                  directory: contentsDirectory,
                  onTap: widget.goToDir,
                  lastCrumbBuilder: lastCrumbBuilder,
                );
              },
            ),
          );
        },
      ),
    );
  }

  InteractiveAppBarTitle _buildAppBarTitle(BuildContext context) {
    final appMode = context.watch<ValueNotifier<AppMode>>().value;
    Widget title = Text(
      context.l10n.explorerPageTitle,
      softWrap: false,
      overflow: TextOverflow.fade,
      maxLines: 1,
    );
    if (appMode == .main) {
      title = SourceStateAwareAppBarTitle(
        title: title,
        source: context.read<CollectionSource>(),
      );
    }
    return InteractiveAppBarTitle(
      onTap: () => _goToSearch(context),
      child: title,
    );
  }

  List<Widget> _buildActions(BuildContext context, double maxWidth) {
    final animations = context.select<Settings, AccessibilityAnimations>((v) => v.accessibilityAnimations);
    return [
      IconButton(
        icon: const Icon(AIcons.search),
        onPressed: () => _goToSearch(context),
        tooltip: MaterialLocalizations.of(context).searchFieldLabel,
      ),
      if (_volumes.length > 1) _buildVolumeSelector(context),
      PopupMenuButton<ExplorerAction>(
        itemBuilder: (context) {
          return [
            ExplorerAction.addShortcut,
            ExplorerAction.setHome,
            ExplorerAction.hide,
            null,
            ExplorerAction.stats,
          ].map<PopupMenuEntry<ExplorerAction>>((v) {
            if (v == null) return const PopupMenuDivider();
            return PopupMenuItem(
              value: v,
              child: MenuRow(text: v.getText(context), icon: v.getIcon()),
            );
          }).toList();
        },
        onSelected: (action) async {
          // wait for the popup menu to hide before proceeding with the action
          await Future.delayed(animations.popUpAnimationDelay * timeDilation);
          final directory = widget.directoryNotifier.value;
          if (directory != null) {
            ExplorerActionDelegate(directory: directory).onActionSelected(context, action);
          }
        },
        popUpAnimationStyle: animations.popUpAnimationStyle,
      ),
    ].map((v) => FontSizeIconTheme(child: v)).toList();
  }

  Widget _buildVolumeSelector(BuildContext context) {
    if (_volumes.length == 2) {
      return ValueListenableBuilder<VolumeRelativeDirectory?>(
        valueListenable: widget.directoryNotifier,
        builder: (context, directory, child) {
          final currentVolume = directory?.volumePath;
          final otherVolume = _volumes.firstWhere((volume) => volume.path != currentVolume);
          final icon = otherVolume.isRemovable ? AIcons.storageCard : AIcons.storageMain;
          return IconButton(
            icon: Icon(icon),
            onPressed: () => widget.goToDir(VolumeRelativeDirectory.volume(otherVolume)),
            tooltip: otherVolume.getDescription(context),
          );
        },
      );
    } else {
      return IconButton(
        icon: const Icon(AIcons.storageCard),
        onPressed: () async {
          _volumes.map((v) {
            final selected = widget.directoryNotifier.value?.volumePath == v.path;
            final icon = v.isRemovable ? AIcons.storageCard : AIcons.storageMain;
            return PopupMenuItem(
              value: v,
              enabled: !selected,
              child: MenuRow(
                text: v.getDescription(context),
                icon: Icon(icon),
              ),
            );
          }).toList();
          final volumePath = widget.directoryNotifier.value?.volumePath;
          final initialVolume = _volumes.firstWhereOrNull((v) => v.path == volumePath);
          final volume = await showAvesDialog<StorageVolume?>(
            context: context,
            builder: (context) => SelectStorageDialog(initialVolume: initialVolume),
            routeSettings: const RouteSettings(name: SelectStorageDialog.routeName),
          );
          if (volume != null) {
            widget.goToDir(VolumeRelativeDirectory.volume(volume));
          }
        },
        tooltip: context.l10n.explorerActionSelectStorageVolume,
      );
    }
  }

  double get appBarContentHeight {
    final textScaler = MediaQuery.textScalerOf(context);
    return textScaler.scale(kToolbarHeight) + CrumbLine.getPreferredHeight(textScaler);
  }

  void _goToSearch(BuildContext context) {
    Navigator.maybeOf(context)?.push(
      CollectionSearchPageRoute(context: context),
    );
  }

  void _goToCollectionPage(BuildContext context, CollectionFilter filter) {
    Navigator.maybeOf(context)?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: CollectionPage.routeName),
        builder: (context) => CollectionPage(
          source: context.read<CollectionSource>(),
          filters: {filter},
        ),
      ),
    );
  }
}

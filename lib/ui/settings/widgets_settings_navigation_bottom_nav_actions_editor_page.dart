import 'dart:async';

import 'package:flutter_media_view/function/settings/enums_accessibility_animations.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/collection/widgets_collection_collection_page.dart';
import 'package:flutter_media_view/ui/common/common_basic_font_size_icon_theme.dart';
import 'package:flutter_media_view/ui/common/common_basic_popup_menu_row.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/dialogs_pick_dialogs_album_pick_page.dart';
import 'package:flutter_media_view/ui/common/dialogs_pick_dialogs_tag_pick_page.dart';
import 'package:flutter_media_view/ui/filter/widgets_filter_grids_common_enums.dart';
import 'package:flutter_media_view/ui/collection/widgets_home_home_page.dart';
import 'package:flutter_media_view/ui/common/navigation_nav_item.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_common_quick_actions_editor_page.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_navigation_drawer_editor_page.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_settings_page.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

class BottomNavigationActionEditorPage extends StatefulWidget {
  static const routeName = '/settings/navigation/bottom_actions';

  static const List<String> settingKeys = [SettingKeys.bottomNavigationActionsKey];

  const BottomNavigationActionEditorPage({super.key});

  @override
  State<BottomNavigationActionEditorPage> createState() => _BottomNavigationActionEditorPageState();
}

class _BottomNavigationActionEditorPageState extends State<BottomNavigationActionEditorPage> {
  late final QuickActionEditorController<AvesNavItem> _controller;

  static final allAvailableActions = [
    NavigationDrawerEditorPage.collectionFilterOptions.map((filter) {
      return AvesNavItem(
        route: CollectionPage.routeName,
        filters: filter != null ? {filter} : null,
      );
    }).toList(),
    [
      HomePage.routeName,
      SettingsPage.routeName,
      ...NavigationDrawerEditorPage.pageOptions,
    ].map((v) {
      return AvesNavItem(
        route: v,
      );
    }).toList(),
  ];

  @override
  void initState() {
    super.initState();
    _controller = QuickActionEditorController(
      load: () => settings.bottomNavigationActions,
      save: (actions) => settings.bottomNavigationActions = actions,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuickActionEditorPage<AvesNavItem>(
      title: context.l10n.settingsNavigationBottomActionEditorPageTitle,
      appBarActions: _buildActions(context),
      bannerText: context.l10n.settingsNavigationBottomActionEditorBanner,
      allAvailableActions: allAvailableActions,
      actionIcon: (context, action) => action.getIcon(context),
      actionText: (context, action) => action.getText(context),
      controller: _controller,
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final animations = context.select<Settings, AccessibilityAnimations>((v) => v.accessibilityAnimations);
    return [
      PopupMenuButton<_EditorAction>(
        itemBuilder: (context) {
          return [
            _EditorAction.addAlbum,
            _EditorAction.addTag,
          ].map<PopupMenuEntry<_EditorAction>>((v) {
            return PopupMenuItem(
              value: v,
              child: MenuRow(text: v.getText(context), icon: v.getIcon()),
            );
          }).toList();
        },
        onSelected: (action) async {
          // wait for the popup menu to hide before proceeding with the action
          await Future.delayed(animations.popUpAnimationDelay * timeDilation);
          await _onActionSelected(context, action);
        },
        popUpAnimationStyle: animations.popUpAnimationStyle,
      ),
    ].map((v) => FontSizeIconTheme(child: v)).toList();
  }

  Future<void> _onActionSelected(BuildContext context, _EditorAction action) async {
    switch (action) {
      case .addAlbum:
        final albumFilter = await pickAlbum(
          context: context,
          moveType: null,
          chipTypes: AlbumChipType.values.toSet(),
          initialGroup: null,
        );
        if (albumFilter == null) return;
        _controller.add(AvesNavItem(route: CollectionPage.routeName, filters: {albumFilter}));
      case .addTag:
        final tagFilter = await pickTag(
          context: context,
          chipTypes: ChipType.values.toSet(),
          initialGroup: null,
        );
        if (tagFilter == null) return;
        _controller.add(AvesNavItem(route: CollectionPage.routeName, filters: {tagFilter}));
    }
  }
}

enum _EditorAction {
  addAlbum,
  addTag,
}

extension _ExtraEditorActionView on _EditorAction {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      _EditorAction.addAlbum => l10n.settingsNavigationDrawerAddAlbum,
      _EditorAction.addTag => l10n.tagEditorPageAddTagTooltip,
    };
  }

  Widget getIcon() => Icon(_getIconData());

  IconData _getIconData() {
    return switch (this) {
      _EditorAction.addAlbum => AIcons.album,
      _EditorAction.addTag => AIcons.tag,
    };
  }
}

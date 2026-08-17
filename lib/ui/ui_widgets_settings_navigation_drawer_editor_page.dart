import 'package:flutter_media_view/function/function_filters_container_album_group.dart';
import 'package:flutter_media_view/function/function_filters.dart';
import 'package:flutter_media_view/function/function_filters_mime.dart';
import 'package:flutter_media_view/function/function_filters_recent.dart';
import 'package:flutter_media_view/function/function_filters_trash.dart';
import 'package:flutter_media_view/function/function_settings.dart';
import 'package:flutter_media_view/function/function_mime_types.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_search_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_explorer_explorer_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_filter_grids_albums_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_filter_grids_countries_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_filter_grids_places_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_filter_grids_tags_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_navigation_drawer_app_drawer.dart';
import 'package:flutter_media_view/ui/ui_widgets_navigation_drawer_tile.dart';
import 'package:flutter_media_view/ui/ui_widgets_search_collection_search_delegate.dart';
import 'package:flutter_media_view/ui/ui_widgets_settings_navigation_drawer_tab_albums.dart';
import 'package:flutter_media_view/ui/ui_widgets_settings_navigation_drawer_tab_fixed.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/material.dart';

class NavigationDrawerEditorPage extends StatefulWidget {
  static const routeName = '/settings/navigation/drawer';

  static const List<String> settingKeys = [
    SettingKeys.drawerTypeBookmarksKey,
    SettingKeys.drawerAlbumBookmarksKey,
    SettingKeys.drawerPageBookmarksKey,
  ];

  static final List<CollectionFilter?> collectionFilterOptions = [
    null,
    RecentlyAddedFilter.instance,
    TrashFilter.instance,
    ...CollectionSearchDelegate.typeFilters,
    MimeFilter(MimeTypes.svg),
  ];
  static const List<String> pageOptions = [
    AlbumListPage.routeName,
    CountryListPage.routeName,
    PlaceListPage.routeName,
    TagListPage.routeName,
    ExplorerPage.routeName,
    SearchPage.routeName,
  ];

  const NavigationDrawerEditorPage({super.key});

  @override
  State<NavigationDrawerEditorPage> createState() => _NavigationDrawerEditorPageState();
}

class _NavigationDrawerEditorPageState extends State<NavigationDrawerEditorPage> {
  final List<CollectionFilter?> _typeItems = [];
  final Set<CollectionFilter?> _visibleTypes = {};
  final List<AlbumBaseFilter> _albumItems = [];
  final List<String> _pageItems = [];
  final Set<String> _visiblePages = {};

  @override
  void initState() {
    super.initState();
    final userTypeLinks = settings.drawerTypeBookmarks;
    _visibleTypes.addAll(userTypeLinks);
    _typeItems.addAll(userTypeLinks);
    _typeItems.addAll(NavigationDrawerEditorPage.collectionFilterOptions.where((v) => !userTypeLinks.contains(v) && v != TrashFilter.instance));

    final userPageLinks = settings.drawerPageBookmarks;
    _visiblePages.addAll(userPageLinks);
    _pageItems.addAll(userPageLinks);
    _pageItems.addAll(NavigationDrawerEditorPage.pageOptions.where((v) => !userPageLinks.contains(v)));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // delayed as `context` should not be used within `initState`
      _albumItems.addAll(AppDrawer.effectiveAlbumBookmarks(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tabs = <(Tab, Widget)>[
      (
        Tab(text: l10n.settingsNavigationDrawerTabTypes),
        DrawerFixedListTab<CollectionFilter?>(
          items: _typeItems,
          visibleItems: _visibleTypes,
          leading: (item) => DrawerFilterIcon(filter: item),
          title: (item) => DrawerFilterTitle(filter: item),
        ),
      ),
      (
        Tab(text: l10n.settingsNavigationDrawerTabAlbums),
        DrawerAlbumTab(
          items: _albumItems,
        ),
      ),
      (
        Tab(text: l10n.settingsNavigationDrawerTabPages),
        DrawerFixedListTab<String>(
          items: _pageItems,
          visibleItems: _visiblePages,
          leading: (item) => DrawerPageIcon(route: item),
          title: (item) => DrawerPageTitle(route: item),
        ),
      ),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: AvesScaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !settings.useTvLayout,
          title: Text(l10n.settingsNavigationDrawerEditorPageTitle),
          bottom: TabBar(
            tabs: tabs.map((t) => t.$1).toList(),
          ),
        ),
        body: PopScope(
          onPopInvokedWithResult: (didPop, result) {
            settings.drawerTypeBookmarks = _typeItems.where(_visibleTypes.contains).toList();
            settings.drawerAlbumBookmarks = _albumItems;
            settings.drawerPageBookmarks = _pageItems.where(_visiblePages.contains).toList();
          },
          child: SafeArea(
            bottom: false,
            child: TabBarView(
              children: tabs.map((t) => t.$2).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter_media_view/function/filters/container_album_group.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/filters/mime.dart';
import 'package:flutter_media_view/function/filters/recent.dart';
import 'package:flutter_media_view/function/filters/filters_trash.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/model/mime_types.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/search/common_search_page.dart';
import 'package:flutter_media_view/ui/common/explorer_page.dart';
import 'package:flutter_media_view/ui/filter/grids_albums_page.dart';
import 'package:flutter_media_view/ui/filter/grids_countries_page.dart';
import 'package:flutter_media_view/ui/filter/grids_places_page.dart';
import 'package:flutter_media_view/ui/filter/grids_tags_page.dart';
import 'package:flutter_media_view/ui/common/navigation_drawer_app_drawer.dart';
import 'package:flutter_media_view/ui/common/navigation_drawer_tile.dart';
import 'package:flutter_media_view/ui/collection/search_delegate.dart';
import 'package:flutter_media_view/ui/settings/navigation_drawer_tab_albums.dart';
import 'package:flutter_media_view/ui/settings/navigation_drawer_tab_fixed.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
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
      child: FmvScaffold(
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

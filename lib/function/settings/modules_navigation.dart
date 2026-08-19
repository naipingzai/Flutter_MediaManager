import 'package:flutter_media_view/function/filters/container_album_group.dart';
import 'package:flutter_media_view/function/filters/container_dynamic_album.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/grouping/common.dart';
import 'package:flutter_media_view/function/settings/defaults.dart';
import 'package:flutter_media_view/ui/collection/widgets_collection_page.dart';
import 'package:flutter_media_view/ui/common/explorer_page.dart';
import 'package:flutter_media_view/ui/filter/widgets_grids_albums_page.dart';
import 'package:flutter_media_view/ui/filter/widgets_grids_tags_page.dart';
import 'package:flutter_media_view/ui/common/navigation_nav_item.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:fmv_utils/flutter_media_view_utils.dart';
import 'package:synchronized/synchronized.dart';

mixin NavigationSettings on SettingsAccess {
  bool get mustBackTwiceToExit => getBool(SettingKeys.mustBackTwiceToExitKey) ?? SettingsDefaults.mustBackTwiceToExit;

  set mustBackTwiceToExit(bool newValue) => set(SettingKeys.mustBackTwiceToExitKey, newValue);

  KeepScreenOn get keepScreenOn => getEnumOrDefault(SettingKeys.keepScreenOnKey, SettingsDefaults.keepScreenOn, KeepScreenOn.values);

  set keepScreenOn(KeepScreenOn newValue) => set(SettingKeys.keepScreenOnKey, newValue.name);

  HomePageSetting get homePage => getEnumOrDefault(SettingKeys.homePageKey, SettingsDefaults.homePage, HomePageSetting.values);

  Set<CollectionFilter> get homeCustomCollection => (getStringList(SettingKeys.homeCustomCollectionKey) ?? []).map(CollectionFilter.fromJson).nonNulls.toSet();

  String? get homeCustomExplorerPath => getString(SettingKeys.homeCustomExplorerPathKey);

  FmvNavItem get homeNavItem {
    switch (homePage) {
      case .collection:
        return FmvNavItem(route: CollectionPage.routeName, filters: homeCustomCollection);
      case .albums:
        return const FmvNavItem(route: AlbumListPage.routeName);
      case .tags:
        return const FmvNavItem(route: TagListPage.routeName);
      case .explorer:
        return FmvNavItem(route: ExplorerPage.routeName, path: homeCustomExplorerPath);
    }
  }

  void setHome(
    HomePageSetting homePage, {
    Set<CollectionFilter> customCollection = const {},
    String? customExplorerPath,
  }) {
    set(SettingKeys.homePageKey, homePage.name);
    set(SettingKeys.homeCustomCollectionKey, customCollection.map((filter) => filter.toJsonString()).toList());
    set(SettingKeys.homeCustomExplorerPathKey, customExplorerPath);
  }

  bool get confirmCreateVault => getBool(SettingKeys.confirmCreateVaultKey) ?? SettingsDefaults.confirm;

  set confirmCreateVault(bool newValue) => set(SettingKeys.confirmCreateVaultKey, newValue);

  bool get confirmDeleteForever => getBool(SettingKeys.confirmDeleteForeverKey) ?? SettingsDefaults.confirm;

  set confirmDeleteForever(bool newValue) => set(SettingKeys.confirmDeleteForeverKey, newValue);

  bool get confirmMoveToBin => getBool(SettingKeys.confirmMoveToBinKey) ?? SettingsDefaults.confirm;

  set confirmMoveToBin(bool newValue) => set(SettingKeys.confirmMoveToBinKey, newValue);

  bool get confirmMoveUndatedItems => getBool(SettingKeys.confirmMoveUndatedItemsKey) ?? SettingsDefaults.confirm;

  set confirmMoveUndatedItems(bool newValue) => set(SettingKeys.confirmMoveUndatedItemsKey, newValue);

  bool get confirmAfterMoveToBin => getBool(SettingKeys.confirmAfterMoveToBinKey) ?? SettingsDefaults.confirm;

  set confirmAfterMoveToBin(bool newValue) => set(SettingKeys.confirmAfterMoveToBinKey, newValue);

  bool get setMetadataDateBeforeFileOp => getBool(SettingKeys.setMetadataDateBeforeFileOpKey) ?? SettingsDefaults.setMetadataDateBeforeFileOp;

  set setMetadataDateBeforeFileOp(bool newValue) => set(SettingKeys.setMetadataDateBeforeFileOpKey, newValue);

  static const _noFilterPlaceholder = '';

  List<CollectionFilter?> get drawerTypeBookmarks => getStringList(SettingKeys.drawerTypeBookmarksKey)?.map((v) => v == _noFilterPlaceholder ? null : CollectionFilter.fromJson(v)).toList() ?? SettingsDefaults.drawerTypeBookmarks;

  set drawerTypeBookmarks(List<CollectionFilter?> newValue) => set(SettingKeys.drawerTypeBookmarksKey, newValue.map((filter) => filter?.toJsonString() ?? _noFilterPlaceholder).toList());

  List<AlbumBaseFilter>? get drawerAlbumBookmarks => getStringList(SettingKeys.drawerAlbumBookmarksKey)?.map(CollectionFilter.fromJson).whereType<AlbumBaseFilter>().toList();

  set drawerAlbumBookmarks(List<AlbumBaseFilter>? newValue) => set(SettingKeys.drawerAlbumBookmarksKey, newValue?.map((filter) => filter.toJsonString()).toList());

  List<String> get drawerPageBookmarks => getStringList(SettingKeys.drawerPageBookmarksKey) ?? SettingsDefaults.drawerPageBookmarks;

  set drawerPageBookmarks(List<String> newValue) => set(SettingKeys.drawerPageBookmarksKey, newValue);

  List<FmvNavItem> get bottomNavigationActions => getStringList(SettingKeys.bottomNavigationActionsKey)?.map(FmvNavItem.fromJson).nonNulls.toList() ?? SettingsDefaults.bottomNavigationActions;

  set bottomNavigationActions(List<FmvNavItem>? newValue) => set(SettingKeys.bottomNavigationActionsKey, newValue?.map((v) => v.toJson()).toList());

  bool get enableBottomNavigationBar => bottomNavigationActions.length >= 2;

  // listening

  final _lockForBookmarks = Lock();

  Future<void> updateBookmarkedDynamicAlbums(Map<DynamicAlbumFilter, DynamicAlbumFilter?> changes) async {
    await _lockForBookmarks.synchronized(() async {
      final _bookmarks = drawerAlbumBookmarks;
      bool changed = false;
      if (_bookmarks != null) {
        changes.forEach((oldFilter, newFilter) {
          if (newFilter != null) {
            changed |= _bookmarks.replace(oldFilter, newFilter);
          } else {
            changed |= _bookmarks.remove(oldFilter);
          }
        });
      }
      if (changed) {
        drawerAlbumBookmarks = _bookmarks;
      }
    });
  }

  Future<void> updateBookmarkedGroup(Uri oldGroupUri, Uri newGroupUri) async {
    await _lockForBookmarks.synchronized(() async {
      final _bookmarks = drawerAlbumBookmarks;
      bool changed = false;
      if (_bookmarks != null) {
        final grouping = FilterGrouping.forUri(oldGroupUri);
        if (grouping != null) {
          final oldFilter = grouping.uriToFilter(oldGroupUri);
          final newFilter = grouping.uriToFilter(newGroupUri);
          if (oldFilter is AlbumBaseFilter && newFilter is AlbumBaseFilter) {
            changed |= _bookmarks.replace(oldFilter, newFilter);
          }
        }
      }
      if (changed) {
        drawerAlbumBookmarks = _bookmarks;
      }
    });
  }
}

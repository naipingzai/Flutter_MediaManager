import 'package:flutter_media_view/function/model/covers.dart';
import 'package:flutter_media_view/function/model/dynamic_albums.dart';
import 'package:flutter_media_view/function/model/favourites.dart';
import 'package:flutter_media_view/function/grouping/common.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_source.dart';
import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:flutter/widgets.dart';

enum AppExportItem { covers, dynamicAlbums, favourites, settings }

extension ExtraAppExportItem on AppExportItem {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      AppExportItem.covers => l10n.appExportCovers,
      AppExportItem.dynamicAlbums => l10n.appExportDynamicAlbums,
      AppExportItem.favourites => l10n.appExportFavourites,
      AppExportItem.settings => l10n.appExportSettings,
    };
  }

  Object? export(CollectionSource source) {
    return switch (this) {
      AppExportItem.covers => covers.export(source),
      AppExportItem.dynamicAlbums => dynamicAlbums.export(),
      AppExportItem.favourites => favourites.export(source),
      AppExportItem.settings => settings.export(),
    };
  }

  Future<void> import(Object jsonObject, CollectionSource source) async {
    switch (this) {
      case .covers:
        covers.import(jsonObject, source);
      case .dynamicAlbums:
        dynamicAlbums.import(jsonObject);
      case .favourites:
        favourites.import(jsonObject, source);
      case .settings:
        await settings.import(jsonObject);
        albumGrouping.setGroups(settings.albumGroups);
        tagGrouping.setGroups(settings.tagGroups);
    }
  }
}

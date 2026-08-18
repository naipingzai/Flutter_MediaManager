import 'dart:convert';

import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/function/source/collection_source.dart';
import 'package:flutter_media_view/ui/about/widgets_about_about_page.dart';
import 'package:flutter_media_view/ui/collection/widgets_collection_collection_page.dart';
import 'package:flutter_media_view/ui/search/widgets_common_search_page.dart';
import 'package:flutter_media_view/ui/common/debug_app_debug_page.dart';
import 'package:flutter_media_view/ui/common/explorer_explorer_page.dart';
import 'package:flutter_media_view/ui/filter/widgets_filter_grids_albums_page.dart';
import 'package:flutter_media_view/ui/filter/widgets_filter_grids_countries_page.dart';
import 'package:flutter_media_view/ui/filter/widgets_filter_grids_places_page.dart';
import 'package:flutter_media_view/ui/filter/widgets_filter_grids_tags_page.dart';
import 'package:flutter_media_view/ui/collection/widgets_home_home_page.dart';
import 'package:flutter_media_view/ui/common/navigation_drawer_tile.dart';
import 'package:flutter_media_view/ui/common/navigation_nav_display.dart';
import 'package:flutter_media_view/ui/collection/widgets_search_collection_search_page_route.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_settings_page.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FmvNavItem extends Equatable {
  final String route;
  final Set<CollectionFilter>? filters;
  final String? path;

  @override
  List<Object?> get props => [route, filters, path];

  const FmvNavItem({
    required this.route,
    this.filters,
    this.path,
  });

  Widget getIcon(BuildContext context) {
    if (route == CollectionPage.routeName) {
      return DrawerFilterIcon(filter: filters?.firstOrNull);
    }

    final textScaler = MediaQuery.textScalerOf(context);
    final iconSize = textScaler.scale(24);
    return Icon(NavigationDisplay.getPageIcon(route), size: iconSize);
  }

  String getText(BuildContext context) {
    if (route == CollectionPage.routeName) {
      return NavigationDisplay.getFilterTitle(context, filters?.firstOrNull);
    }
    return NavigationDisplay.getPageTitle(context, route);
  }

  Future<void> goTo(BuildContext context, {bool? topLevel}) async {
    topLevel ??= _defaultTopLevel;
    final route = routeBuilder(context, topLevel: topLevel);
    if (topLevel) {
      await Navigator.maybeOf(context)?.pushAndRemoveUntil(
        route,
        (route) => false,
      );
    } else {
      await Navigator.maybeOf(context)?.push(route);
    }
  }

  bool get _defaultTopLevel {
    switch (route) {
      case AboutPage.routeName:
      case AppDebugPage.routeName:
      case SearchPage.routeName:
      case SettingsPage.routeName:
        return false;
      default:
        return true;
    }
  }

  Route routeBuilder(BuildContext context, {required bool topLevel}) {
    switch (route) {
      case HomePage.routeName:
        return settings.homeNavItem.routeBuilder(context, topLevel: topLevel);
      case SearchPage.routeName:
        final currentCollection = context.read<CollectionLens?>();
        return CollectionSearchPageRoute(
          context: context,
          parentCollection: topLevel ? currentCollection?.copyWith() : currentCollection,
        );
      default:
        return MaterialPageRoute(
          settings: RouteSettings(name: route),
          builder: _materialPageBuilder(route),
        );
    }
  }

  WidgetBuilder _materialPageBuilder(String route) {
    switch (route) {
      case CollectionPage.routeName:
        return (context) => CollectionPage(
          source: context.read<CollectionSource>(),
          filters: filters,
        );
      case AlbumListPage.routeName:
        return (_) => const AlbumListPage(initialGroup: null);
      case CountryListPage.routeName:
        return (_) => const CountryListPage();
      case PlaceListPage.routeName:
        return (_) => const PlaceListPage();
      case TagListPage.routeName:
        return (_) => const TagListPage(initialGroup: null);
      case AboutPage.routeName:
        return (_) => const AboutPage();
      case AppDebugPage.routeName:
        return (_) => const AppDebugPage();
      case ExplorerPage.routeName:
        return (_) => ExplorerPage(path: path);
      case SettingsPage.routeName:
        return (_) => const SettingsPage();
      default:
        throw Exception('unknown route=$route');
    }
  }

  // serialization

  static FmvNavItem _fromMap(Map<String, Object?> json) {
    return FmvNavItem(
      route: json['route'] as String,
      filters: (json['filters'] as List?)?.map(CollectionFilter.fromJson).nonNulls.toSet(),
      path: json['path'] as String?,
    );
  }

  Map<String, Object?> _toMap() => {
    'route': route,
    if (filters != null) 'filters': filters!.map((v) => v.toJsonMap()).toList(),
    'path': ?path,
  };

  String toJson() => jsonEncode(_toMap());

  static FmvNavItem? fromJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;

    try {
      final jsonMap = jsonDecode(jsonString);
      if (jsonMap is Map<String, Object?>) {
        return _fromMap(jsonMap);
      }
      debugPrint('failed to parse navigation item from json=$jsonString');
    } catch (error) {
      // no need for stack
      debugPrint('failed to parse navigation item from json=$jsonString error=$error');
    }
    return null;
  }
}

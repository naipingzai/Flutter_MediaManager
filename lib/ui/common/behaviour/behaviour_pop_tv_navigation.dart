import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/function/source/collection_lens.dart';
import 'package:fmv/ui/collection/page.dart';
import 'package:fmv/ui/common/behaviour/behaviour_pop_scope.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

final TvNavigationPopHandler tvNavigationPopHandler = TvNavigationPopHandler._private();

// address `TV-DB` requirement from https://developer.android.com/docs/quality-guidelines/tv-app-quality
class TvNavigationPopHandler implements PopHandler {
  TvNavigationPopHandler._private();

  @override
  bool canPop(BuildContext context) {
    if (context.select<Settings, bool>((v) => !v.useTvLayout)) return true;
    if (_isHome(context)) return true;
    return false;
  }

  @override
  void onPopBlocked(BuildContext context) {
    Navigator.maybeOf(context)?.pushAndRemoveUntil(
      settings.homeNavItem.routeBuilder(context, topLevel: true),
      (route) => false,
    );
  }

  static bool _isHome(BuildContext context) {
    final home = settings.homeNavItem;
    final currentRoute = context.currentRouteName;

    if (currentRoute != home.route) return false;

    switch (home.route) {
      case CollectionPage.routeName:
        return context.read<CollectionLens>().filters.isEmpty;
      default:
        return true;
    }
  }
}

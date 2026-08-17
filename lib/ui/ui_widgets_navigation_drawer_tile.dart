import 'package:flutter_media_view/function/function_filters.dart';
import 'package:flutter_media_view/ui/ui_theme_colors.dart';
import 'package:flutter_media_view/ui/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/ui_widgets_debug_app_debug_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_navigation_nav_display.dart';
import 'package:flutter/material.dart';

class DrawerFilterIcon extends StatelessWidget {
  final CollectionFilter? filter;

  const DrawerFilterIcon({
    super.key,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final iconSize = textScaler.scale(24);

    final _filter = filter;
    if (_filter == null) return Icon(AIcons.allCollection, size: iconSize);
    return _filter.iconBuilder(context, iconSize) ?? const SizedBox();
  }
}

class DrawerFilterTitle extends StatelessWidget {
  final CollectionFilter? filter;

  const DrawerFilterTitle({
    super.key,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) => Text(NavigationDisplay.getFilterTitle(context, filter));
}

class DrawerPageIcon extends StatelessWidget {
  final String route;

  const DrawerPageIcon({
    super.key,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final icon = NavigationDisplay.getPageIcon(route);
    if (icon != null) {
      switch (route) {
        case AppDebugPage.routeName:
          return ShaderMask(
            shaderCallback: AvesColorsData.debugGradient.createShader,
            blendMode: BlendMode.srcIn,
            child: Icon(icon),
          );
        default:
          return Icon(icon);
      }
    }
    return const SizedBox();
  }
}

class DrawerPageTitle extends StatelessWidget {
  final String route;

  const DrawerPageTitle({
    super.key,
    required this.route,
  });

  @override
  Widget build(BuildContext context) => Text(NavigationDisplay.getPageTitle(context, route));
}

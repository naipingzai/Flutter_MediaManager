import 'package:flutter_media_view/app_mode.dart';
import 'package:flutter_media_view/function/settings/function_settings.dart';
import 'package:flutter_media_view/function/source/function_source_collection_lens.dart';
import 'package:flutter_media_view/ui/collection/ui_widgets_collection_collection_page.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_basic_draggable_scrollbar_notifications.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_media_query.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_identity_aves_app_bar.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_navigation_nav_bar_floating.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_navigation_nav_item.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppBottomNavBar extends StatefulWidget {
  final Stream<DraggableScrollbarEvent> events;

  // collection loaded in the `CollectionPage`, if any
  final CollectionLens? currentCollection;

  static double get height => kBottomNavigationBarHeight + AvesFloatingBar.margin.vertical;

  const AppBottomNavBar({
    super.key,
    required this.events,
    this.currentCollection,
  });

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar> {
  String? _lastRoute;

  @override
  void initState() {
    super.initState();
    _registerWidget(widget);
  }

  @override
  void didUpdateWidget(covariant AppBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
  }

  @override
  void dispose() {
    _unregisterWidget(widget);
    super.dispose();
  }

  void _registerWidget(AppBottomNavBar widget) {
    widget.currentCollection?.filterChangeNotifier.addListener(_onCollectionFilterChanged);
  }

  void _unregisterWidget(AppBottomNavBar widget) {
    widget.currentCollection?.filterChangeNotifier.removeListener(_onCollectionFilterChanged);
  }

  @override
  Widget build(BuildContext context) {
    final items = context.select<Settings, List<AvesNavItem>>((v) => v.bottomNavigationActions);
    if (items.length < 2) return const SizedBox();

    Widget child = FloatingNavBar(
      scrollController: PrimaryScrollController.of(context),
      events: widget.events,
      childHeight: AppBottomNavBar.height + context.select<MediaQueryData, double>((mq) => mq.effectiveBottomPadding),
      child: SafeArea(
        child: AvesFloatingBar(
          builder: (context, backgroundColor, child) => BottomNavigationBar(
            items: items.map((item) {
              final label = item.getText(context);
              return BottomNavigationBarItem(
                icon: item.getIcon(context),
                label: label,
                tooltip: label,
              );
            }).toList(),
            onTap: (index) => _goTo(context, items, index),
            currentIndex: _getCurrentIndex(context, items),
            type: BottomNavigationBarType.fixed,
            backgroundColor: backgroundColor,
            showSelectedLabels: false,
            showUnselectedLabels: false,
          ),
        ),
      ),
    );

    final animate = context.select<Settings, bool>((v) => v.animate);
    if (animate) {
      child = Hero(
        tag: 'nav-bar',
        flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
          return MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: toHeroContext.widget,
          );
        },
        child: child,
      );
    }

    return child;
  }

  void _onCollectionFilterChanged() => setState(() {});

  int _getCurrentIndex(BuildContext context, List<AvesNavItem> items) {
    // current route may be null during navigation
    final currentRoute = context.currentRouteName ?? _lastRoute;
    _lastRoute = currentRoute;

    final currentItem = items.firstWhereOrNull((item) {
      final itemRoute = item.route;
      if (currentRoute != itemRoute) return false;

      switch (itemRoute) {
        case CollectionPage.routeName:
          final currentFilters = widget.currentCollection?.filters ?? {};
          return const SetEquality().equals(currentFilters, item.filters ?? {});
        default:
          return true;
      }
    });
    final currentIndex = currentItem != null ? items.indexOf(currentItem) : 0;
    return currentIndex;
  }

  void _goTo(BuildContext context, List<AvesNavItem> items, int index) {
    final item = items[index];
    item.goTo(context, topLevel: null);
  }
}

class NavBarPaddingSliver extends StatelessWidget {
  const NavBarPaddingSliver({super.key});

  @override
  Widget build(BuildContext context) {
    final canNavigate = context.select<ValueNotifier<AppMode>, bool>((v) => v.value.canNavigate);
    final enableBottomNavigationBar = context.select<Settings, bool>((v) => v.enableBottomNavigationBar);
    final showBottomNavigationBar = canNavigate && enableBottomNavigationBar;
    return SliverToBoxAdapter(
      child: SizedBox(height: showBottomNavigationBar ? AppBottomNavBar.height : 0),
    );
  }
}

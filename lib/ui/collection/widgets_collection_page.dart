import 'dart:async';

import 'package:flutter_media_view/core/app_mode.dart';
import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/filters/query.dart';
import 'package:flutter_media_view/function/filters/filters_trash.dart';
import 'package:flutter_media_view/function/utils/function_highlight.dart';
import 'package:flutter_media_view/function/model/function_selection.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/function/source/collection_source.dart';
import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view/ui/common/view.dart';
import 'package:flutter_media_view/ui/collection/widgets_collection_grid.dart';
import 'package:flutter_media_view/ui/collection/widgets_entry_set_action_delegate.dart';
import 'package:flutter_media_view/ui/common/common_basic_draggable_scrollbar_notifications.dart';
import 'package:flutter_media_view/ui/common/common_basic_insets.dart';
import 'package:flutter_media_view/ui/common/common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/common/common_behaviour_pop_double_back.dart';
import 'package:flutter_media_view/ui/common/common_behaviour_pop_scope.dart';
import 'package:flutter_media_view/ui/common/common_behaviour_pop_tv_navigation.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/common_identity_fmv_fab.dart';
import 'package:flutter_media_view/ui/common/common_providers_query_provider.dart';
import 'package:flutter_media_view/ui/common/common_providers_selection_provider.dart';
import 'package:flutter_media_view/ui/common/navigation_drawer_app_drawer.dart';
import 'package:flutter_media_view/ui/common/navigation_nav_bar.dart';
import 'package:flutter_media_view/ui/common/navigation_tv_rail.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CollectionPage extends StatefulWidget {
  static const routeName = '/collection';

  final CollectionSource source;
  final Set<CollectionFilter?>? filters;
  final bool Function(FmvEntry element)? highlightTest;

  const CollectionPage({
    super.key,
    required this.source,
    required this.filters,
    this.highlightTest,
  });

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final Set<StreamSubscription> _subscriptions = {};
  late CollectionLens _collection;
  final StreamController<DraggableScrollbarEvent> _draggableScrollBarEventStreamController = StreamController.broadcast();

  @override
  void initState() {
    // do not seed this widget with the collection, but control its lifecycle here instead,
    // as the collection properties may change and they should not be reset by a widget update (e.g. with theme change)
    _collection = CollectionLens(
      source: widget.source,
      filters: widget.filters,
    );
    super.initState();
    _subscriptions.add(
      settings.updateStream.where((event) => event.key == SettingKeys.enableBinKey).listen((_) {
        if (!settings.enableBin) {
          _collection.removeFilter(TrashFilter.instance);
        }
      }),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitHighlight());
  }

  @override
  void dispose() {
    _subscriptions
      ..forEach((sub) => sub.cancel())
      ..clear();
    _collection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useTvLayout = settings.useTvLayout;
    final liveFilter = _collection.filters.firstWhereOrNull((v) => v is QueryFilter && v.live) as QueryFilter?;
    return SelectionProvider<FmvEntry>(
      toSelectableItems: (entry) => entry.toSelectableItems(),
      child: Selector<Selection<FmvEntry>, (bool, int)>(
        selector: (context, selection) => (selection.isSelecting, selection.selectedItemCount),
        builder: (context, selectionResult, child) {
          final (isSelecting, selectedItemCount) = selectionResult;
          final body = QueryProvider(
            startEnabled: settings.getShowTitleQuery(context.currentRouteName!),
            initialQuery: liveFilter?.query,
            child: Builder(
              builder: (context) {
                return FmvPopScope(
                  handlers: [
                    APopHandler(
                      canPop: (context) => context.select<Selection<FmvEntry>, bool>((v) => !v.isSelecting),
                      onPopBlocked: (context) => context.read<Selection<FmvEntry>>().browse(),
                    ),
                    tvNavigationPopHandler,
                    doubleBackPopHandler,
                  ],
                  child: GestureAreaProtectorStack(
                    child: DirectionalSafeArea(
                      start: !useTvLayout,
                      top: false,
                      bottom: false,
                      child: const CollectionGrid(
                        // key is expected by test driver
                        key: Key('collection-grid'),
                        settingsRouteKey: CollectionPage.routeName,
                      ),
                    ),
                  ),
                );
              },
            ),
          );

          Widget page;
          if (useTvLayout) {
            page = FmvScaffold(
              body: Row(
                children: [
                  TvRail(
                    controller: context.read<TvRailController>(),
                    currentCollection: _collection,
                  ),
                  Expanded(child: body),
                ],
              ),
              resizeToAvoidBottomInset: false,
              extendBody: true,
            );
          } else {
            page = Selector<Settings, bool>(
              selector: (context, s) => s.enableBottomNavigationBar,
              builder: (context, enableBottomNavigationBar, child) {
                final canNavigate = context.select<ValueNotifier<AppMode>, bool>((v) => v.value.canNavigate);
                final showBottomNavigationBar = canNavigate && enableBottomNavigationBar;

                return NotificationListener<DraggableScrollbarNotification>(
                  onNotification: (notification) {
                    _draggableScrollBarEventStreamController.add(notification.event);
                    return false;
                  },
                  child: FmvScaffold(
                    body: body,
                    floatingActionButton: _buildFab(context, isSelecting, selectedItemCount),
                    drawer: canNavigate ? AppDrawer(currentCollection: _collection) : null,
                    bottomNavigationBar: showBottomNavigationBar
                        ? AppBottomNavBar(
                            events: _draggableScrollBarEventStreamController.stream,
                            currentCollection: _collection,
                          )
                        : null,
                    resizeToAvoidBottomInset: false,
                    extendBody: true,
                  ),
                );
              },
            );
          }
          // this provider should be above `TvRail`
          return ChangeNotifierProvider<CollectionLens>.value(
            value: _collection,
            child: page,
          );
        },
      ),
    );
  }

  Widget? _buildFab(BuildContext context, bool isSelecting, int selectedItemCount) {
    final actionDelegate = EntrySetActionDelegate();
    final action = EntrySetActions.fab.firstWhereOrNull((action) {
      return actionDelegate.isVisible(
        action,
        appMode: context.watch<ValueNotifier<AppMode>>().value,
        isSelecting: isSelecting,
        itemCount: _collection.entryCount,
        selectedItemCount: selectedItemCount,
        isTrash: _collection.filters.contains(TrashFilter.instance),
      );
    });

    if (action != null) {
      final canApply = actionDelegate.canApply(
        action,
        isSelecting: isSelecting,
        collection: _collection,
        selectedItemCount: selectedItemCount,
      );

      return FmvFab(
        tooltip: action.getText(context),
        icon: action.getIcon(),
        onPressed: canApply ? () => actionDelegate.onActionSelected(context, action) : null,
      );
    }

    return null;
  }

  Future<void> _checkInitHighlight() async {
    final highlightTest = widget.highlightTest;
    if (highlightTest == null) return;

    final item = _collection.sortedEntries.firstWhereOrNull(highlightTest);
    if (item == null) return;

    final delayDuration = context.read<DurationsData>().staggeredAnimationPageTarget;
    await Future.delayed(delayDuration + ADurations.highlightScrollInitDelay);

    if (!mounted) return;
    final animate = context.read<Settings>().animate;
    context.read<HighlightInfo>().trackItem(item, animate: animate, highlightItem: item);
  }
}

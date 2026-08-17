import 'package:flutter_media_view/app_mode.dart';
import 'package:flutter_media_view/function/function_entry.dart';
import 'package:flutter_media_view/function/function_filters_query.dart';
import 'package:flutter_media_view/function/function_settings.dart';
import 'package:flutter_media_view/function/function_source_collection_lens.dart';
import 'package:flutter_media_view/ui/widgets/collection/collection_grid.dart';
import 'package:flutter_media_view/ui/widgets/collection/collection_page.dart';
import 'package:flutter_media_view/ui/widgets/common/basic/insets.dart';
import 'package:flutter_media_view/ui/widgets/common/basic/scaffold.dart';
import 'package:flutter_media_view/ui/widgets/common/extensions/build_context.dart';
import 'package:flutter_media_view/ui/widgets/common/providers/query_provider.dart';
import 'package:flutter_media_view/ui/widgets/common/providers/selection_provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ItemPickPage extends StatefulWidget {
  static const routeName = '/item_pick';

  final CollectionLens collection;
  final bool canRemoveFilters;

  const ItemPickPage({
    super.key,
    required this.collection,
    required this.canRemoveFilters,
  });

  @override
  State<ItemPickPage> createState() => _ItemPickPageState();
}

class _ItemPickPageState extends State<ItemPickPage> {
  final ValueNotifier<AppMode> _appModeNotifier = ValueNotifier(.initialization);

  @override
  void dispose() {
    _appModeNotifier.dispose();
    // provided collection should be a new instance specifically created
    // for the `ItemPickPage` widget, so it can be safely disposed here
    widget.collection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    final liveFilter = collection.filters.firstWhereOrNull((v) => v is QueryFilter && v.live) as QueryFilter?;
    _appModeNotifier.value = widget.canRemoveFilters ? .pickUnfilteredMediaInternal : .pickFilteredMediaInternal;
    return ListenableProvider<ValueNotifier<AppMode>>.value(
      value: _appModeNotifier,
      child: AvesScaffold(
        body: SelectionProvider<AvesEntry>(
          toSelectableItems: (entry) => entry.toSelectableItems(),
          child: QueryProvider(
            startEnabled: settings.getShowTitleQuery(context.currentRouteName!),
            initialQuery: liveFilter?.query,
            child: GestureAreaProtectorStack(
              child: SafeArea(
                top: false,
                bottom: false,
                child: ChangeNotifierProvider<CollectionLens>.value(
                  value: collection,
                  child: const CollectionGrid(
                    settingsRouteKey: CollectionPage.routeName,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

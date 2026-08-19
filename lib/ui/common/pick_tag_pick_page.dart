import 'package:flutter_media_view/core/app_mode.dart';
import 'package:flutter_media_view/function/filters/container_tag_group.dart';
import 'package:flutter_media_view/function/filters/covered_tag.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/grouping/common.dart';
import 'package:flutter_media_view/function/model/function_selection.dart';
import 'package:flutter_media_view/function/settings/enums_accessibility_animations.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_source.dart';
import 'package:flutter_media_view/function/source/tag.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/view.dart';
import 'package:flutter_media_view/ui/common/actions/mixins_feedback.dart';
import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:flutter_media_view/ui/filter/identity_fmv_filter_chip.dart';
import 'package:flutter_media_view/ui/common/identity/identity_buttons_captioned_button.dart';
import 'package:flutter_media_view/ui/common/identity/identity_empty.dart';
import 'package:flutter_media_view/ui/filter/common_providers_group_provider.dart';
import 'package:flutter_media_view/ui/common/providers_query_provider.dart';
import 'package:flutter_media_view/ui/common/providers_selection_provider.dart';
import 'package:flutter_media_view/ui/common/dialogs_fmv_dialog.dart';
import 'package:flutter_media_view/ui/editor/filter_edit_create_group_dialog.dart';
import 'package:flutter_media_view/ui/filter/grids/common_action_delegates_tag_set.dart';
import 'package:flutter_media_view/ui/filter/grids/common_app_bar.dart';
import 'package:flutter_media_view/ui/filter/grids/common_enums.dart';
import 'package:flutter_media_view/ui/filter/grids/grid_page.dart';
import 'package:flutter_media_view/ui/filter/grids/tags_page.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

Future<TagBaseFilter?> pickTag({
  required BuildContext context,
  required Set<ChipType> chipTypes,
  required Uri? initialGroup,
  GroupUriPredicate? isValidGroupPick,
}) async {
  final source = context.read<CollectionSource>();
  if (source.targetScope != CollectionSource.fullScope) {
    await reportService.log('Complete source initialization to pick tag');
    // source may not be fully initialized in view mode
    source.canAnalyze = true;
    await source.init(scope: CollectionSource.fullScope);
  }
  return await Navigator.maybeOf(context)?.push<TagBaseFilter>(
    MaterialPageRoute(
      settings: const RouteSettings(name: _TagPickPage.routeName),
      builder: (context) => _TagPickPage(
        source: source,
        chipTypes: chipTypes,
        initialGroup: initialGroup,
        isValidGroupPick: isValidGroupPick,
      ),
    ),
  );
}

class _TagPickPage extends StatefulWidget {
  static const routeName = '/tag_pick';

  final CollectionSource source;
  final Set<ChipType> chipTypes;
  final Uri? initialGroup;
  final GroupUriPredicate? isValidGroupPick;

  const _TagPickPage({
    required this.source,
    required this.chipTypes,
    required this.initialGroup,
    required this.isValidGroupPick,
  });

  @override
  State<_TagPickPage> createState() => _TagPickPageState();
}

class _TagPickPageState extends State<_TagPickPage> with FeedbackMixin {
  final ValueNotifier<double> _appBarHeightNotifier = ValueNotifier(0);
  final ValueNotifier<AppMode> _appModeNotifier = ValueNotifier(.pickFilterInternal);

  CollectionSource get source => widget.source;

  Set<ChipType> get chipTypes => widget.chipTypes;

  bool get isPickingGroup => chipTypes.length == 1 && chipTypes.contains(ChipType.group);

  bool get canPickGroupFromCrumbLine => chipTypes.length == ChipType.values.length;

  String get title {
    final l10n = context.l10n;
    if (isPickingGroup) {
      return l10n.groupPickerTitle;
    } else {
      return l10n.tagPickPageTitle;
    }
  }

  @override
  void dispose() {
    _appBarHeightNotifier.dispose();
    _appModeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableProvider<ValueNotifier<AppMode>>.value(
      value: _appModeNotifier,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<FilterGrouping>.value(value: tagGrouping),
          FilterGroupProvider(initialValue: widget.initialGroup),
        ],
        child: Builder(
          // to access filter group provider from subtree context
          builder: (context) {
            return Selector<Settings, ChipSortFactor>(
              selector: (context, s) => s.tagSortFactor,
              builder: (context, s, child) {
                return StreamBuilder(
                  stream: source.eventBus.on<TagsChangedEvent>(),
                  builder: (context, snapshot) {
                    final groupUri = context.watch<FilterGroupNotifier>().value;
                    final gridItems = TagListPage.getGridItems(source, chipTypes, groupUri);
                    final scrollController = PrimaryScrollController.of(context);
                    return SelectionProvider<FilterGridItem<TagBaseFilter>>(
                      child: QueryProvider(
                        startEnabled: settings.getShowTitleQuery(context.currentRouteName!),
                        child: FilterGridPage<TagBaseFilter>(
                          settingsRouteKey: TagListPage.routeName,
                          appBar: FilterGridAppBar(
                            source: source,
                            title: title,
                            actionDelegate: TagChipSetActionDelegate(gridItems),
                            actionsBuilder: _buildActions,
                            appBarHeightNotifier: _appBarHeightNotifier,
                            scrollController: scrollController,
                            onGroupCrumbTap: canPickGroupFromCrumbLine ? _pickFilter : null,
                          ),
                          appBarHeightNotifier: _appBarHeightNotifier,
                          scrollController: scrollController,
                          sections: TagListPage.groupToSections(gridItems),
                          newFilters: const {},
                          sortFactor: settings.tagSortFactor,
                          showHeaders: false,
                          selectable: false,
                          emptyBuilder: () => isPickingGroup
                              ? EmptyContent(
                                  icon: AIcons.group,
                                  text: context.l10n.groupEmpty,
                                )
                              : EmptyContent(
                                  icon: AIcons.tag,
                                  text: context.l10n.tagEmpty,
                                ),
                          heroType: HeroType.never,
                          floatingActionButton: _buildFab(context),
                          onTileTap: (gridItem, _) async {
                            final filter = gridItem.filter;
                            switch (filter) {
                              case TagGroupFilter _:
                                context.read<FilterGroupNotifier>().value = filter.uri;
                              case TagFilter _:
                                _pickFilter(context, filter);
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget? _buildFab(BuildContext context) {
    return isPickingGroup
        ? Selector<FilterGroupNotifier, Uri?>(
            selector: (context, v) => v.value,
            builder: (context, groupUri, child) {
              final isValid = widget.isValidGroupPick?.call(groupUri) ?? true;
              return FloatingActionButton.extended(
                onPressed: isValid
                    ? () {
                        final filter = groupUri != null ? tagGrouping.uriToFilter(groupUri) : TagGroupFilter.root;
                        if (filter is TagBaseFilter) {
                          _pickFilter(context, filter);
                        }
                      }
                    : null,
                backgroundColor: isValid ? null : Theme.of(context).disabledColor,
                icon: const Icon(AIcons.apply),
                label: Text(context.l10n.groupPickerUseThisGroupButton),
              );
            },
          )
        : null;
  }

  List<Widget> _buildActions(
    BuildContext context,
    AppMode appMode,
    Selection<FilterGridItem<TagBaseFilter>> selection,
    TagChipSetActionDelegate actionDelegate,
  ) {
    final itemCount = actionDelegate.allItems.length;
    final isSelecting = selection.isSelecting;
    final selectedFilters = selection.selectedItems.map((v) => v.filter).toSet();

    bool isVisible(ChipSetAction action) => actionDelegate.isVisible(
      action,
      appMode: appMode,
      isSelecting: isSelecting,
      itemCount: itemCount,
      selectedFilters: selectedFilters,
    );

    void onActionSelected(ChipSetAction action) {
      switch (action) {
        case .createGroup:
          final parentGroupUri = context.read<FilterGroupNotifier>().value;
          _createGroup(parentGroupUri);
        default:
          actionDelegate.onActionSelected(context, action);
      }
    }

    return settings.useTvLayout
        ? _buildTelevisionActions(
            context: context,
            isVisible: isVisible,
            onActionSelected: onActionSelected,
          )
        : _buildMobileActions(
            context: context,
            isVisible: isVisible,
            onActionSelected: onActionSelected,
          );
  }

  List<Widget> _buildTelevisionActions({
    required BuildContext context,
    required bool Function(ChipSetAction action) isVisible,
    required void Function(ChipSetAction action) onActionSelected,
  }) {
    return [
      ...ChipSetActions.general,
    ].where(isVisible).map((action) {
      return CaptionedButton(
        icon: action.getIcon(),
        caption: action.getText(context),
        onPressed: () => onActionSelected(action),
      );
    }).toList();
  }

  List<Widget> _buildMobileActions({
    required BuildContext context,
    required bool Function(ChipSetAction action) isVisible,
    required void Function(ChipSetAction action) onActionSelected,
  }) {
    final animations = context.select<Settings, AccessibilityAnimations>((v) => v.accessibilityAnimations);

    final quickActions = [
      if (isPickingGroup) ChipSetAction.createGroup,
    ];

    // `null` items are converted to dividers
    final menuActions = [
      ...ChipSetActions.general,
      null,
      ChipSetAction.toggleTitleSearch,
    ];

    return [
      ...quickActions
          .where(isVisible)
          .map(
            (action) => IconButton(
              icon: action.getIcon(),
              onPressed: () => onActionSelected(action),
              tooltip: action.getText(context),
            ),
          ),
      PopupMenuButton<ChipSetAction>(
        itemBuilder: (context) {
          return menuActions.where((v) => v == null || isVisible(v)).map((action) {
            if (action == null) return const PopupMenuDivider();
            return FilterGridAppBar.toMenuItem(context, action, enabled: true);
          }).toList();
        },
        onSelected: (action) async {
          // remove focus, if any, to prevent the keyboard from showing up
          // after the user is done with the popup menu
          FocusManager.instance.primaryFocus?.unfocus();

          // wait for the popup menu to hide before proceeding with the action
          await Future.delayed(animations.popUpAnimationDelay * timeDilation);
          onActionSelected(action);
        },
        popUpAnimationStyle: animations.popUpAnimationStyle,
      ),
    ];
  }

  Future<void> _createGroup(Uri? parentGroupUri) async {
    final uri = await showFmvDialog<Uri>(
      context: context,
      builder: (context) => CreateGroupDialog(grouping: tagGrouping, parentGroupUri: parentGroupUri),
      routeSettings: const RouteSettings(name: CreateGroupDialog.routeName),
    );
    if (uri == null) return;

    // wait for the dialog to hide
    await Future.delayed(ADurations.dialogTransitionLoose * timeDilation);

    _pickFilter(context, TagGroupFilter.empty(uri));
  }

  void _pickFilter(BuildContext context, TagBaseFilter filter) async {
    Navigator.maybeOf(context)?.pop<TagBaseFilter>(filter);
  }
}

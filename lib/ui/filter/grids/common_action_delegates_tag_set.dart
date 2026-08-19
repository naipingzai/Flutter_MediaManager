import 'package:fmv/core/app_mode.dart';
import 'package:fmv/function/filters/container_tag_group.dart';
import 'package:fmv/function/filters/covered_tag.dart';
import 'package:fmv/function/filters/filters.dart';
import 'package:fmv/function/grouping/common.dart';
import 'package:fmv/function/grouping/convert.dart';
import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/function/source/collection_source.dart';
import 'package:fmv/function/common/services.dart';
import 'package:fmv/ui/collection/entry_set_action_delegate.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv/ui/filter/common_providers_group_provider.dart';
import 'package:fmv/ui/common/dialogs_fmv_confirmation_dialog.dart';
import 'package:fmv/ui/common/pick_tag_pick_page.dart';
import 'package:fmv/ui/filter/grids/common_action_delegates_chip_set.dart';
import 'package:fmv/ui/filter/grids/common_enums.dart';
import 'package:fmv/ui/filter/grids/tags_page.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TagChipSetActionDelegate extends ChipSetActionDelegate<TagBaseFilter> {
  final Iterable<FilterGridItem<TagBaseFilter>> _items;

  TagChipSetActionDelegate(Iterable<FilterGridItem<TagBaseFilter>> items) : _items = items;

  @override
  Iterable<FilterGridItem<TagBaseFilter>> get allItems => _items;

  @override
  ChipSortFactor get sortFactor => settings.tagSortFactor;

  @override
  set sortFactor(ChipSortFactor factor) => settings.tagSortFactor = factor;

  @override
  bool get sortReverse => settings.tagSortReverse;

  @override
  set sortReverse(bool value) => settings.tagSortReverse = value;

  @override
  TileLayout get tileLayout => settings.getTileLayout(TagListPage.routeName);

  @override
  set tileLayout(TileLayout tileLayout) => settings.setTileLayout(TagListPage.routeName, tileLayout);

  @override
  bool isVisible(
    ChipSetAction action, {
    required AppMode appMode,
    required bool isSelecting,
    required int itemCount,
    required Set<TagBaseFilter> selectedFilters,
  }) {
    final isMain = appMode == .main;
    final useTvLayout = settings.useTvLayout;

    switch (action) {
      case .createGroup:
        return true;
      case .group:
        return isMain && isSelecting && !useTvLayout;
      case .remove:
        return isMain && isSelecting && !settings.isReadOnly && (selectedFilters.isEmpty || selectedFilters.every((v) => v is TagFilter));
      default:
        return super.isVisible(
          action,
          appMode: appMode,
          isSelecting: isSelecting,
          itemCount: itemCount,
          selectedFilters: selectedFilters,
        );
    }
  }

  @override
  bool canApply(
    ChipSetAction action, {
    required bool isSelecting,
    required int itemCount,
    required Set<TagBaseFilter> selectedFilters,
  }) {
    switch (action) {
      case .delete:
        return selectedFilters.isNotEmpty && selectedFilters.every((v) => v is TagFilter);
      default:
        return super.canApply(
          action,
          isSelecting: isSelecting,
          itemCount: itemCount,
          selectedFilters: selectedFilters,
        );
    }
  }

  @override
  void onActionSelected(BuildContext context, ChipSetAction action) {
    reportService.log('$runtimeType handles $action');
    switch (action) {
      // single/multiple filters
      case .remove:
        _remove(context);
      case .group:
        _group(context);
      default:
        break;
    }
    super.onActionSelected(context, action);
  }

  Future<void> _remove(BuildContext context) async {
    final l10n = context.l10n;

    if (!await showConfirmationDialog(
      context: context,
      message: l10n.genericDangerWarningDialogMessage,
      ok: l10n.applyButtonLabel,
    )) {
      return;
    }

    final filters = getSelectedFilters(context).whereType<TagFilter>().toSet();
    final source = context.read<CollectionSource>();

    await EntrySetActionDelegate().removeTags(
      context,
      entries: source.visibleEntries.where((entry) => filters.any((f) => f.test(entry))).toSet(),
      tags: filters.map((v) => v.tag).toSet(),
    );

    browse(context);
  }

  Future<void> _group(BuildContext context) async {
    final filters = getSelectedFilters(context);
    final childrenUris = filters.map(GroupingConversion.filterToUri).nonNulls.toSet();

    final initialGroup = tagGrouping.getFilterParent(filters.first);
    final filter = await pickTag(
      context: context,
      chipTypes: {ChipType.group},
      initialGroup: initialGroup,
      isValidGroupPick: (destinationGroupUri) {
        return FilterGrouping.isValidParent(destinationGroupUri, childrenUris);
      },
    );
    if (filter == null) return;

    final destinationGroupUri = filter is TagGroupFilter ? filter.uri : null;
    tagGrouping.addToGroup(childrenUris, destinationGroupUri);
    context.read<FilterGroupNotifier>().value = destinationGroupUri;

    final source = context.read<CollectionSource>();
    source.invalidateTagGroupFilterSummary(notify: true);
    browse(context);
  }
}

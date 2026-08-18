import 'package:flutter_media_view/app_mode.dart';
import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_props.dart';
import 'package:flutter_media_view/function/function_selection.dart';
import 'package:flutter_media_view/function/settings/enums_accessibility_animations.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/theme/themes.dart';
import 'package:flutter_media_view/ui/common/view.dart';
import 'package:flutter_media_view/ui/common/common_app_bar_app_bar_title.dart';
import 'package:flutter_media_view/ui/common/common_app_bar_sliver_app_bar_title.dart';
import 'package:flutter_media_view/ui/common/common_basic_font_size_icon_theme.dart';
import 'package:flutter_media_view/ui/common/common_basic_popup_menu_row.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/search/widgets_common_search_route.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_action_entry_info_action_delegate.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_info_info_search_delegate.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_info_metadata_metadata_dir.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

class InfoAppBar extends StatelessWidget {
  final AvesEntry entry;
  final CollectionLens? collection;
  final EntryInfoActionDelegate actionDelegate;
  final ValueNotifier<Map<String, MetadataDirectory>> metadataNotifier;
  final VoidCallback onBackPressed;

  const InfoAppBar({
    super.key,
    required this.entry,
    required this.collection,
    required this.actionDelegate,
    required this.metadataNotifier,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<ValueNotifier<AppMode>>().value;
    bool isVisible(EntryAction action) => actionDelegate.isVisible(
      appMode: appMode,
      targetEntry: entry,
      action: action,
    );
    final commonActions = EntryActions.commonMetadataActions.where(isVisible);
    final formatSpecificActions = EntryActions.formatSpecificMetadataActions.where(isVisible);
    final useTvLayout = settings.useTvLayout;
    final animations = context.select<Settings, AccessibilityAnimations>((v) => v.accessibilityAnimations);
    return SliverAppBar(
      leading: useTvLayout
          ? null
          : FontSizeIconTheme(
              child: IconButton(
                // key is expected by test driver
                key: const Key('back-button'),
                icon: const Icon(AIcons.goUp),
                onPressed: onBackPressed,
                tooltip: context.l10n.viewerInfoBackToViewerTooltip,
              ),
            ),
      automaticallyImplyLeading: false,
      title: SliverAppBarTitleWrapper(
        child: InteractiveAppBarTitle(
          onTap: () => _goToSearch(context),
          child: Text(context.l10n.viewerInfoPageTitle),
        ),
      ),
      actions: useTvLayout
          ? []
          : [
              IconButton(
                icon: const Icon(AIcons.search),
                onPressed: () => _goToSearch(context),
                tooltip: MaterialLocalizations.of(context).searchFieldLabel,
              ),
              if (entry.canEdit)
                PopupMenuButton<EntryAction>(
                  itemBuilder: (context) => [
                    ...commonActions.map((action) => _toMenuItem(context, action, enabled: actionDelegate.canApply(entry, action))),
                    if (formatSpecificActions.isNotEmpty) ...[
                      const PopupMenuDivider(),
                      ...formatSpecificActions.map((action) => _toMenuItem(context, action, enabled: actionDelegate.canApply(entry, action))),
                    ],
                    if (isVisible(EntryAction.debug)) ...[
                      const PopupMenuDivider(),
                      _toMenuItem(context, EntryAction.debug, enabled: true),
                    ],
                  ],
                  onSelected: (action) async {
                    // wait for the popup menu to hide before proceeding with the action
                    await Future.delayed(animations.popUpAnimationDelay * timeDilation);
                    await actionDelegate.onActionSelected(context, entry, collection, action);
                  },
                  popUpAnimationStyle: animations.popUpAnimationStyle,
                ),
            ].map((v) => FontSizeIconTheme(child: v)).toList(),
      floating: true,
      // as of Flutter v3.44.4, `SliverAppBar` does not automatically pick up `systemOverlayStyle` from `AppBar` theme
      systemOverlayStyle: Theme.of(context).appBarTheme.systemOverlayStyle,
    );
  }

  PopupMenuItem<EntryAction> _toMenuItem(BuildContext context, EntryAction action, {required bool enabled}) {
    return PopupMenuItem(
      value: action,
      enabled: enabled,
      child: MenuRow(text: action.getText(context), icon: action.getIcon()),
    );
  }

  void _goToSearch(BuildContext context) {
    final isSelecting = context.read<Selection<AvesEntry>?>()?.isSelecting ?? false;
    Navigator.maybeOf(context)?.push(
      SearchPageRoute(
        delegate: InfoSearchDelegate(
          searchFieldLabel: context.l10n.viewerInfoSearchFieldLabel,
          searchFieldStyle: Themes.searchFieldStyle(context),
          entry: entry,
          metadataNotifier: metadataNotifier,
          isSelecting: isSelecting,
        ),
        background: Theme.of(context).scaffoldBackgroundColor,
      ),
    );
  }
}

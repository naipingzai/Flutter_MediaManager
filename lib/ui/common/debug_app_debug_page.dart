import 'dart:async';
import 'dart:math';

import 'package:flutter_media_view/function/model/favourites.dart';
import 'package:flutter_media_view/function/filters/covered_location.dart';
import 'package:flutter_media_view/function/filters/covered_tag.dart';
import 'package:flutter_media_view/function/filters/path.dart';
import 'package:flutter_media_view/function/settings/enums_accessibility_animations.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_source.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_font_size_icon_theme.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_popup_menu_row.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/common/behaviour/common_behaviour_pop_scope.dart';
import 'package:flutter_media_view/ui/common/behaviour/common_behaviour_pop_tv_navigation.dart';
import 'package:flutter_media_view/ui/common/common_extensions_media_query.dart';
import 'package:flutter_media_view/ui/common/debug_app_debug_action.dart';
import 'package:flutter_media_view/ui/common/debug_cache.dart';
import 'package:flutter_media_view/ui/common/debug_capabilities.dart';
import 'package:flutter_media_view/ui/common/debug_colors.dart';
import 'package:flutter_media_view/ui/common/debug_database.dart';
import 'package:flutter_media_view/ui/common/debug_general.dart';
import 'package:flutter_media_view/ui/common/debug_groups.dart';
import 'package:flutter_media_view/ui/common/debug_hdr.dart';
import 'package:flutter_media_view/ui/common/debug_leaking.dart';
import 'package:flutter_media_view/ui/common/debug_media_store_scan_dialog.dart';
import 'package:flutter_media_view/ui/common/debug_os_apps.dart';
import 'package:flutter_media_view/ui/common/debug_os_codecs.dart';
import 'package:flutter_media_view/ui/common/debug_os_paths.dart';
import 'package:flutter_media_view/ui/common/debug_os_storage.dart';
import 'package:flutter_media_view/ui/settings/widgets_debug_settings.dart';
import 'package:flutter_media_view/ui/common/dialogs_fmv_dialog.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

class AppDebugPage extends StatelessWidget {
  static const routeName = '/debug';

  const AppDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final animations = context.select<Settings, AccessibilityAnimations>((v) => v.accessibilityAnimations);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: FmvScaffold(
        appBar: AppBar(
          title: const Text('Debug'),
          actions: [
            FontSizeIconTheme(
              child: PopupMenuButton<AppDebugAction>(
                // key is expected by test driver
                key: const Key('appbar-menu-button'),
                itemBuilder: (context) => AppDebugAction.values
                    .map(
                      (v) => PopupMenuItem(
                        // key is expected by test driver
                        key: Key('menu-${v.name}'),
                        value: v,
                        child: MenuRow(text: v.name),
                      ),
                    )
                    .toList(),
                onSelected: (action) async {
                  // wait for the popup menu to hide before proceeding with the action
                  await Future.delayed(animations.popUpAnimationDelay * timeDilation);
                  unawaited(_onActionSelected(context, action));
                },
                popUpAnimationStyle: animations.popUpAnimationStyle,
              ),
            ),
          ],
        ),
        body: FmvPopScope(
          handlers: [tvNavigationPopHandler],
          child: SafeArea(
            bottom: false,
            child: Selector<MediaQueryData, double>(
              selector: (context, mq) => max(mq.effectiveBottomPadding, mq.systemGestureInsets.bottom),
              builder: (context, mqPaddingBottom, child) {
                return ListView(
                  padding: const EdgeInsets.all(8) + EdgeInsets.only(bottom: mqPaddingBottom),
                  children: const [
                    DebugGeneralSection(),
                    DebugAppDatabaseSection(),
                    DebugCacheSection(),
                    DebugCapabilitiesSection(),
                    DebugColorSection(),
                    DebugHdrSection(),
                    DebugLeakingSection(),
                    DebugSettingsSection(),
                    DebugGroupsSection(),
                    DebugOSAppSection(),
                    DebugOSCodecSection(),
                    DebugOSPathSection(),
                    DebugOSStorageSection(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onActionSelected(BuildContext context, AppDebugAction action) async {
    switch (action) {
      case .prepScreenshotThumbnails:
        // get source beforehand, as widget may be unmounted during action handling
        final source = context.read<CollectionSource>();
        settings.changeFilterVisibility(settings.hiddenFilters, true);
        settings.changeFilterVisibility({
          TagFilter('fmv-thumbnail', reversed: true),
        }, false);
        await favourites.clear();
        await favourites.add(source.visibleEntries);
      case .prepScreenshotStats:
        settings.changeFilterVisibility(settings.hiddenFilters, true);
        settings.changeFilterVisibility({
          PathFilter('/storage/emulated/0/Pictures/Dev'),
        }, false);
      case .prepScreenshotCountries:
        settings.changeFilterVisibility({
          LocationFilter(LocationLevel.country, 'Belgium;BE'),
          LocationFilter(LocationLevel.country, 'Croatia;HR'),
        }, false);
      case .mediaStoreScanDir:
        // scan files copied from test assets
        // we do it via the app instead of broadcasting via ADB
        // because `MEDIA_SCANNER_SCAN_FILE` intent got deprecated in API 29
        await showFmvDialog<String>(
          context: context,
          builder: (context) => const MediaStoreScanDirDialog(),
        );
      case .greenScreen:
        await Navigator.maybeOf(context)?.push(
          MaterialPageRoute(
            builder: (context) => const Scaffold(
              backgroundColor: Colors.green,
              body: SizedBox(),
            ),
          ),
        );
    }
  }
}

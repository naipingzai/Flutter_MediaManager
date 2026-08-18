import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/common/view.dart';
import 'package:flutter_media_view/ui/common/common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_common_collection_tile.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_common_tiles.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ScreenSaverSettingsPage extends StatelessWidget {
  static const routeName = '/settings/screen_saver';

  const ScreenSaverSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FmvScaffold(
      appBar: AppBar(
        title: Text(l10n.settingsScreenSaverPageTitle),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            SettingsSwitchListTile(
              selector: (context, s) => s.screenSaverFillScreen,
              onChanged: (v) => settings.screenSaverFillScreen = v,
              title: (_) => l10n.settingsSlideshowFillScreen,
            ),
            SettingsSwitchListTile(
              selector: (context, s) => s.screenSaverAnimatedZoomEffect,
              onChanged: (v) => settings.screenSaverAnimatedZoomEffect = v,
              title: (_) => l10n.settingsSlideshowAnimatedZoomEffect,
            ),
            SettingsSelectionListTile<ViewerTransition>(
              values: ViewerTransition.values,
              getName: (context, v) => v.getName(context),
              selector: (context, s) => s.screenSaverTransition,
              onSelection: (v) => settings.screenSaverTransition = v,
              tileTitle: (_) => l10n.settingsSlideshowTransitionTile,
            ),
            SettingsDurationListTile(
              selector: (context, s) => s.screenSaverInterval,
              onChanged: (v) => settings.screenSaverInterval = v,
              title: (_) => l10n.settingsSlideshowIntervalTile,
            ),
            SettingsSelectionListTile<SlideshowVideoPlayback>(
              values: SlideshowVideoPlayback.values,
              getName: (context, v) => v.getName(context),
              selector: (context, s) => s.screenSaverVideoPlayback,
              onSelection: (v) => settings.screenSaverVideoPlayback = v,
              tileTitle: (_) => l10n.settingsSlideshowVideoPlaybackTile,
              dialogTitle: l10n.settingsSlideshowVideoPlaybackDialogTitle,
            ),
            Selector<Settings, Set<CollectionFilter>>(
              selector: (context, s) => s.screenSaverCollectionFilters,
              builder: (context, filters, child) {
                return SettingsCollectionTile(
                  filters: filters,
                  onSelection: (v) => settings.screenSaverCollectionFilters = v,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/ui/common/view.dart';
import 'package:fmv/ui/common/basic/basic_scaffold.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv/ui/settings/common/tiles.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

class ViewerSlideshowPage extends StatelessWidget {
  static const routeName = '/settings/viewer/slideshow';

  static const List<String> settingKeys = [
    SettingKeys.slideshowRepeatKey,
    SettingKeys.slideshowShuffleKey,
    SettingKeys.slideshowFillScreenKey,
    SettingKeys.slideshowAnimatedZoomEffectKey,
    SettingKeys.slideshowTransitionKey,
    SettingKeys.slideshowIntervalKey,
    SettingKeys.slideshowVideoPlaybackKey,
  ];

  const ViewerSlideshowPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FmvScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !settings.useTvLayout,
        title: Text(l10n.settingsViewerSlideshowPageTitle),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            SettingsSwitchListTile(
              selector: (context, s) => s.slideshowRepeat,
              onChanged: (v) => settings.slideshowRepeat = v,
              title: (_) => l10n.settingsSlideshowRepeat,
            ),
            SettingsSwitchListTile(
              selector: (context, s) => s.slideshowShuffle,
              onChanged: (v) => settings.slideshowShuffle = v,
              title: (_) => l10n.settingsSlideshowShuffle,
            ),
            SettingsSwitchListTile(
              selector: (context, s) => s.slideshowFillScreen,
              onChanged: (v) => settings.slideshowFillScreen = v,
              title: (_) => l10n.settingsSlideshowFillScreen,
            ),
            SettingsSwitchListTile(
              selector: (context, s) => s.slideshowAnimatedZoomEffect,
              onChanged: (v) => settings.slideshowAnimatedZoomEffect = v,
              title: (_) => l10n.settingsSlideshowAnimatedZoomEffect,
            ),
            SettingsSelectionListTile<ViewerTransition>(
              values: ViewerTransition.values,
              getName: (context, v) => v.getName(context),
              selector: (context, s) => s.slideshowTransition,
              onSelection: (v) => settings.slideshowTransition = v,
              tileTitle: (_) => l10n.settingsSlideshowTransitionTile,
            ),
            SettingsDurationListTile(
              selector: (context, s) => s.slideshowInterval,
              onChanged: (v) => settings.slideshowInterval = v,
              title: (_) => l10n.settingsSlideshowIntervalTile,
            ),
            SettingsSelectionListTile<SlideshowVideoPlayback>(
              values: SlideshowVideoPlayback.values,
              getName: (context, v) => v.getName(context),
              selector: (context, s) => s.slideshowVideoPlayback,
              onSelection: (v) => settings.slideshowVideoPlayback = v,
              tileTitle: (_) => l10n.settingsSlideshowVideoPlaybackTile,
              dialogTitle: l10n.settingsSlideshowVideoPlaybackDialogTitle,
            ),
          ],
        ),
      ),
    );
  }
}

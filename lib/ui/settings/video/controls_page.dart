import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/ui/common/basic/basic_scaffold.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv/ui/settings/common/tiles.dart';
import 'package:fmv/ui/settings/video/control_buttons_page.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

class VideoControlsPage extends StatelessWidget {
  static const routeName = '/settings/video/controls';

  static const List<String> settingKeys = [
    ...VideoControlButtonsPage.settingKeys,
    SettingKeys.videoGestureDoubleTapTogglePlayKey,
    SettingKeys.videoGestureSideDoubleTapSeekKey,
    SettingKeys.videoGestureVerticalDragBrightnessVolumeKey,
  ];

  const VideoControlsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FmvScaffold(
      appBar: AppBar(
        title: Text(l10n.settingsVideoControlsPageTitle),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            SettingsSubPageTile(
              title: (_) => l10n.settingsVideoButtonsTile,
              routeName: VideoControlButtonsPage.routeName,
              builder: (context) => const VideoControlButtonsPage(),
            ),
            SettingsSwitchListTile(
              selector: (context, s) => s.videoGestureDoubleTapTogglePlay,
              onChanged: (v) => settings.videoGestureDoubleTapTogglePlay = v,
              title: (_) => l10n.settingsVideoGestureDoubleTapTogglePlay,
            ),
            SettingsSwitchListTile(
              selector: (context, s) => s.videoGestureSideDoubleTapSeek,
              onChanged: (v) => settings.videoGestureSideDoubleTapSeek = v,
              title: (_) => l10n.settingsVideoGestureSideDoubleTapSeek,
            ),
            SettingsSwitchListTile(
              selector: (context, s) => s.videoGestureVerticalDragBrightnessVolume,
              onChanged: (v) => settings.videoGestureVerticalDragBrightnessVolume = v,
              title: (_) => l10n.settingsVideoGestureVerticalDragBrightnessVolume,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter_media_view/function/function_device.dart';
import 'package:flutter_media_view/function/function_settings.dart';
import 'package:flutter_media_view/ui/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/ui_view.dart';
import 'package:flutter_media_view/ui/ui_widgets_about_app_ref.dart';
import 'package:flutter_media_view/ui/ui_widgets_aves_app.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/ui_widgets_settings_common_tiles.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

class VideoPlaybackPage extends StatelessWidget {
  static const routeName = '/settings/video/playback';

  static const List<String> settingKeys = [
    SettingKeys.videoAutoPlayModeKey,
    SettingKeys.videoLoopModeKey,
    SettingKeys.videoResumptionModeKey,
    SettingKeys.videoBackgroundModeKey,
    SettingKeys.videoHardwareAccelerationKey,
  ];

  const VideoPlaybackPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AvesScaffold(
      appBar: AppBar(
        title: Text(l10n.settingsVideoPlaybackPageTitle),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            SettingsSelectionListTile<VideoAutoPlayMode>(
              values: VideoAutoPlayMode.values,
              getName: (context, v) => v.getName(context),
              selector: (context, s) => s.videoAutoPlayMode,
              onSelection: (v) => settings.videoAutoPlayMode = v,
              tileTitle: (_) => l10n.settingsVideoAutoPlay,
            ),
            SettingsSelectionListTile<VideoLoopMode>(
              values: VideoLoopMode.values,
              getName: (context, v) => v.getName(context),
              selector: (context, s) => s.videoLoopMode,
              onSelection: (v) => settings.videoLoopMode = v,
              tileTitle: (_) => l10n.settingsVideoLoopModeTile,
              dialogTitle: l10n.settingsVideoLoopModeDialogTitle,
            ),
            SettingsSelectionListTile<VideoResumptionMode>(
              values: VideoResumptionMode.values,
              getName: (context, v) => v.getName(context),
              selector: (context, s) => s.videoResumptionMode,
              onSelection: (v) => settings.videoResumptionMode = v,
              tileTitle: (_) => l10n.settingsVideoResumptionModeTile,
              dialogTitle: l10n.settingsVideoResumptionModeDialogTitle,
            ),
            if (!settings.useTvLayout && device.supportPictureInPicture)
              SettingsSelectionListTile<VideoBackgroundMode>(
                values: VideoBackgroundMode.values,
                getName: (context, v) => v.getName(context),
                selector: (context, s) => s.videoBackgroundMode,
                onSelection: (v) => settings.videoBackgroundMode = v,
                tileTitle: (_) => l10n.settingsVideoBackgroundMode,
                dialogTitle: l10n.settingsVideoBackgroundModeDialogTitle,
              ),
            SettingsSelectionListTile<VideoHardwareAcceleration>(
              values: VideoHardwareAcceleration.values,
              getName: (context, v) => v.getName(context),
              selector: (context, s) => s.videoHardwareAcceleration,
              onSelection: (v) => settings.videoHardwareAcceleration = v,
              tileTitle: (_) => l10n.settingsVideoEnableHardwareAcceleration,
              trailingBuilder: (context) => IconButton(
                icon: const Icon(AIcons.help),
                onPressed: () => AvesApp.launchUrl('${AppReference.avesFaq}#should-i-enable-hardware-acceleration-to-play-videos'),
                tooltip: 'FAQ',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

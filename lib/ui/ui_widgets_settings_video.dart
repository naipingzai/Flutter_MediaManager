import 'dart:async';

import 'package:flutter_media_view/function/function_filters_mime.dart';
import 'package:flutter_media_view/function/function_settings.dart';
import 'package:flutter_media_view/ui/ui_theme_colors.dart';
import 'package:flutter_media_view/ui/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/ui_widgets_settings_common_tile_leading.dart';
import 'package:flutter_media_view/ui/ui_widgets_settings_common_tiles.dart';
import 'package:flutter_media_view/ui/ui_widgets_settings_settings_definition.dart';
import 'package:flutter_media_view/ui/ui_widgets_settings_video_controls_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_settings_video_playback_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_settings_video_subtitle_theme_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VideoSection extends SettingsSection {
  final bool standalonePage;

  VideoSection({
    this.standalonePage = false,
  });

  @override
  String get key => 'video';

  @override
  Widget icon(BuildContext context) => SettingsTileLeading(
    icon: AIcons.video,
    color: context.select<AvesColorsData, Color>((v) => v.video),
  );

  @override
  String title(BuildContext context) => context.l10n.settingsVideoSectionTitle;

  @override
  Future<List<SettingsTile>> tiles(BuildContext context) async {
    return [
      if (!standalonePage) SettingsTileVideoShowVideos(),
      SettingsTileVideoPlayback(),
      if (!settings.useTvLayout) SettingsTileVideoControls(),
      SettingsTileVideoSubtitleTheme(),
    ];
  }
}

class SettingsTileVideoShowVideos extends SettingsTile {
  @override
  List<String> get settingKeys => []; // prefer main hidden filter setting page

  @override
  String title(BuildContext context) => context.l10n.settingsVideoShowVideos;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => !s.hiddenFilters.contains(MimeFilter.video),
    onChanged: (v) => settings.changeFilterVisibility({MimeFilter.video}, v),
    title: title,
  );
}

class SettingsTileVideoPlayback extends SettingsTile {
  @override
  List<String> get settingKeys => VideoPlaybackPage.settingKeys;

  @override
  String title(BuildContext context) => context.l10n.settingsVideoPlaybackTile;

  @override
  Widget build(BuildContext context) => SettingsSubPageTile(
    title: title,
    routeName: VideoPlaybackPage.routeName,
    builder: (context) => const VideoPlaybackPage(),
  );
}

class SettingsTileVideoControls extends SettingsTile {
  @override
  List<String> get settingKeys => VideoControlsPage.settingKeys;

  @override
  String title(BuildContext context) => context.l10n.settingsVideoControlsTile;

  @override
  Widget build(BuildContext context) => SettingsSubPageTile(
    title: title,
    routeName: VideoControlsPage.routeName,
    builder: (context) => const VideoControlsPage(),
  );
}

class SettingsTileVideoSubtitleTheme extends SettingsTile {
  @override
  List<String> get settingKeys => SubtitleThemePage.settingKeys;

  @override
  String title(BuildContext context) => context.l10n.settingsSubtitleThemeTile;

  @override
  Widget build(BuildContext context) => SettingsSubPageTile(
    title: title,
    routeName: SubtitleThemePage.routeName,
    builder: (context) => const SubtitleThemePage(),
  );
}

import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/settings/settings_definition.dart';
import 'package:flutter_media_view/ui/settings/settings_video.dart';
import 'package:flutter/material.dart';

class VideoSettingsPage extends StatefulWidget {
  static const routeName = '/settings/video';

  const VideoSettingsPage({super.key});

  @override
  State<VideoSettingsPage> createState() => _VideoSettingsPageState();
}

class _VideoSettingsPageState extends State<VideoSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FmvScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !settings.useTvLayout,
        title: Text(context.l10n.settingsVideoPageTitle),
      ),
      body: Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.copyWith(
            // dense style font for tile subtitles, without modifying title font
            bodyMedium: const TextStyle(fontSize: 12),
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<SettingsTile>>(
            future: VideoSection(standalonePage: true).tiles(context),
            builder: (context, snapshot) {
              final tiles = snapshot.data;
              if (tiles == null) return const SizedBox();

              return ListView(
                children: tiles.map((v) => v.build(context)).toList(),
              );
            },
          ),
        ),
      ),
    );
  }
}

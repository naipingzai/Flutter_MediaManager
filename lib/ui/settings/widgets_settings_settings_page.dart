import 'dart:math';

import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view/ui/common/common_extensions_media_query.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_accessibility.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_display.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_language.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_navigation.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_privacy.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_settings_definition.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_settings_mobile_page.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_settings_tv_page.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_thumbnails.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_video.dart';
import 'package:flutter_media_view/ui/viewer/widgets_settings_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fmv_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  static const routeName = '/settings';

  static final List<SettingsSection> sections = [
    NavigationSection(),
    ThumbnailsSection(),
    ViewerSection(),
    VideoSection(),
    PrivacySection(),
    AccessibilitySection(),
    DisplaySection(),
    LanguageSection(),
  ];

  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (settings.useTvLayout) {
      return const SettingsTvPage();
    } else {
      return const SettingsMobilePage();
    }
  }
}

class SettingsListView extends StatelessWidget {
  final List<Widget> children;

  const SettingsListView({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.copyWith(
          // dense style font for tile subtitles, without modifying title font
          bodyMedium: const TextStyle(fontSize: 12),
        ),
      ),
      child: Selector<MediaQueryData, double>(
        selector: (context, mq) => max(mq.effectiveBottomPadding, mq.systemGestureInsets.bottom),
        builder: (context, mqPaddingBottom, child) {
          final durations = context.watch<DurationsData>();
          return ListView(
            padding: const EdgeInsets.all(8) + EdgeInsets.only(bottom: mqPaddingBottom),
            children: AnimationConfiguration.toStaggeredList(
              duration: durations.staggeredAnimation,
              delay: durations.staggeredAnimationDelay * timeDilation,
              childAnimationBuilder: (child) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: child,
                ),
              ),
              children: children,
            ),
          );
        },
      ),
    );
  }
}

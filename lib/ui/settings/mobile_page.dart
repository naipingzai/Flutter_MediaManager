import 'package:fmv/function/settings/enums_accessibility_animations.dart';
import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/ui/theme/icons.dart';
import 'package:fmv/ui/common/actions/mixins_feedback.dart';
import 'package:fmv/ui/common/app_bar_app_bar_title.dart';
import 'package:fmv/ui/common/basic/basic_font_size_icon_theme.dart';
import 'package:fmv/ui/common/basic/basic_insets.dart';
import 'package:fmv/ui/common/basic/basic_popup_menu_row.dart';
import 'package:fmv/ui/common/basic/basic_scaffold.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv/ui/settings/action_delegate.dart';
import 'package:fmv/ui/settings/page.dart';
import 'package:fmv/ui/settings/search_page_route.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fmv_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';

class SettingsMobilePage extends StatefulWidget {
  const SettingsMobilePage({super.key});

  @override
  State<SettingsMobilePage> createState() => _SettingsMobilePageState();
}

class _SettingsMobilePageState extends State<SettingsMobilePage> with FeedbackMixin {
  final ValueNotifier<String?> _expandedNotifier = ValueNotifier(null);

  @override
  void dispose() {
    _expandedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animations = context.select<Settings, AccessibilityAnimations>((v) => v.accessibilityAnimations);
    return FmvScaffold(
      appBar: AppBar(
        title: InteractiveAppBarTitle(
          onTap: () => _goToSearch(context),
          child: Text(context.l10n.settingsPageTitle),
        ),
        actions: [
          IconButton(
            icon: const Icon(AIcons.search),
            onPressed: () => _goToSearch(context),
            tooltip: MaterialLocalizations.of(context).searchFieldLabel,
          ),
          PopupMenuButton<SettingsAction>(
            itemBuilder: (context) {
              return [
                PopupMenuItem(
                  value: SettingsAction.export,
                  child: MenuRow(text: context.l10n.settingsActionExport, icon: const Icon(AIcons.fileExport)),
                ),
                PopupMenuItem(
                  value: SettingsAction.import,
                  child: MenuRow(text: context.l10n.settingsActionImport, icon: const Icon(AIcons.fileImport)),
                ),
              ];
            },
            onSelected: (action) async {
              // wait for the popup menu to hide before proceeding with the action
              await Future.delayed(animations.popUpAnimationDelay * timeDilation);
              SettingsActionDelegate().onActionSelected(context, action);
            },
            popUpAnimationStyle: animations.popUpAnimationStyle,
          ),
        ].map((v) => FontSizeIconTheme(child: v)).toList(),
      ),
      body: GestureAreaProtectorStack(
        child: SafeArea(
          bottom: false,
          child: AnimationLimiter(
            child: SettingsListView(
              children: SettingsPage.sections.map((v) => v.build(context, _expandedNotifier)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _goToSearch(BuildContext context) {
    Navigator.maybeOf(context)?.push(
      SettingsSearchPageRoute(context: context),
    );
  }
}

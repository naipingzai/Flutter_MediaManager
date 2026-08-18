import 'package:flutter_media_view/ui/theme/ui_theme_themes.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/search/ui_widgets_common_search_route.dart';
import 'package:flutter_media_view/ui/settings/ui_widgets_settings_settings_page.dart';
import 'package:flutter_media_view/ui/settings/ui_widgets_settings_settings_search_delegate.dart';
import 'package:flutter/material.dart';

class SettingsSearchPageRoute extends SearchPageRoute {
  SettingsSearchPageRoute({
    required BuildContext context,
    super.background,
  }) : super(
         delegate: SettingsSearchDelegate(
           searchFieldLabel: context.l10n.settingsSearchFieldLabel,
           searchFieldStyle: Themes.searchFieldStyle(context),
           sections: SettingsPage.sections,
         ),
       );
}

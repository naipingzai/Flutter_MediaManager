import 'package:flutter_media_view/theme/themes.dart';
import 'package:flutter_media_view/widgets/common/extensions/build_context.dart';
import 'package:flutter_media_view/widgets/common/search/route.dart';
import 'package:flutter_media_view/widgets/settings/settings_page.dart';
import 'package:flutter_media_view/widgets/settings/settings_search_delegate.dart';
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

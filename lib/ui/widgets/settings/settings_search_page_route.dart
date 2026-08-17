import 'package:flutter_media_view/ui/theme/themes.dart';
import 'package:flutter_media_view/ui/widgets/common/extensions/build_context.dart';
import 'package:flutter_media_view/ui/widgets/common/search/route.dart';
import 'package:flutter_media_view/ui/widgets/settings/settings_page.dart';
import 'package:flutter_media_view/ui/widgets/settings/settings_search_delegate.dart';
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

import 'package:fmv/ui/theme/themes.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv/ui/search/common_search_route.dart';
import 'package:fmv/ui/settings/page.dart';
import 'package:fmv/ui/settings/search_delegate.dart';
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

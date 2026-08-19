import 'dart:collection';
import 'dart:ui' as ui;

import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/ui/common/fmv_app.dart';
import 'package:fmv/ui/common/basic/basic_list_tiles_reselectable_radio.dart';
import 'package:fmv/ui/common/basic/basic_query_bar.dart';
import 'package:fmv/ui/common/basic/basic_scaffold.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv/ui/settings/language/locale_tile.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class LocaleSelectionPage extends StatefulWidget {
  static const routeName = '/settings/locale';

  const LocaleSelectionPage({super.key});

  @override
  State<LocaleSelectionPage> createState() => _LocaleSelectionPageState();
}

class _LocaleSelectionPageState extends State<LocaleSelectionPage> {
  late ui.Locale _selectedValue;
  final ValueNotifier<String> _queryNotifier = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    _selectedValue = settings.basicLocale ?? LocaleTile.systemLocaleOption;
  }

  @override
  void dispose() {
    _queryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useTvLayout = settings.useTvLayout;
    return FmvScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !useTvLayout,
        title: Text(context.l10n.settingsLanguagePageTitle),
      ),
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<String>(
          valueListenable: _queryNotifier,
          builder: (context, query, child) {
            final upQuery = query.toUpperCase().trim();
            return RadioGroup<ui.Locale>(
              groupValue: _selectedValue,
              onChanged: (v) => Navigator.maybeOf(context)?.pop<ui.Locale>(v),
              child: ListView(
                children: [
                  if (!useTvLayout)
                    QueryBar(
                      queryNotifier: _queryNotifier,
                      leadingPadding: const EdgeInsetsDirectional.only(start: 24, end: 8),
                    ),
                  ..._getLocaleOptions(context).entries
                      .where((kv) {
                        if (upQuery.isEmpty) return true;
                        final title = kv.value;
                        return title.toUpperCase().contains(upQuery);
                      })
                      .map((kv) {
                        final value = kv.key;
                        final title = kv.value;
                        return ReselectableRadioListTile<ui.Locale>(
                          // key is expected by test driver
                          key: Key(value.toString()),
                          value: value,
                          reselectable: true,
                          title: Text(
                            title,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            maxLines: 1,
                          ),
                        );
                      }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  LinkedHashMap<ui.Locale, String> _getLocaleOptions(BuildContext context) {
    final displayLocales = FmvApp.supportedLocales.map((locale) => MapEntry(locale, LocaleTile.getLocaleName(locale))).toList()..sort((a, b) => compareAsciiUpperCase(a.value, b.value));

    return LinkedHashMap.of({
      LocaleTile.systemLocaleOption: context.l10n.settingsSystemDefault,
      ...LinkedHashMap.fromEntries(displayLocales),
    });
  }
}

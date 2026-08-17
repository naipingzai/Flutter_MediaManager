import 'package:flutter_media_view/ui/ui_widgets_common_basic_insets.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_behaviour_pop_scope.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_behaviour_pop_tv_navigation.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/ui_widgets_navigation_tv_rail.dart';
import 'package:flutter_media_view/ui/ui_widgets_settings_settings_definition.dart';
import 'package:flutter_media_view/ui/ui_widgets_settings_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsTvPage extends StatelessWidget {
  const SettingsTvPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AvesScaffold(
      body: AvesPopScope(
        handlers: [tvNavigationPopHandler],
        child: Row(
          children: [
            TvRail(
              controller: context.read<TvRailController>(),
            ),
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  DirectionalSafeArea(
                    start: false,
                    bottom: false,
                    child: AppBar(
                      automaticallyImplyLeading: false,
                      title: Text(context.l10n.settingsPageTitle),
                      elevation: 0,
                      primary: false,
                    ),
                  ),
                  const Expanded(
                    child: _Content(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatefulWidget {
  const _Content();

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  final ValueNotifier<int> _indexNotifier = ValueNotifier(0);

  @override
  void dispose() {
    _indexNotifier.dispose();
    super.dispose();
  }

  static final List<SettingsSection> sections = SettingsPage.sections;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _indexNotifier,
      builder: (context, selectedIndex, child) {
        final rail = NavigationRail(
          extended: true,
          destinations: sections
              .map(
                (section) => NavigationRailDestination(
                  icon: section.icon(context),
                  label: Text(section.title(context)),
                ),
              )
              .toList(),
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => _indexNotifier.value = index,
          minExtendedWidth: TvRail.minExtendedWidth,
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                MediaQuery.removePadding(
                  context: context,
                  removeLeft: true,
                  removeTop: true,
                  removeRight: true,
                  removeBottom: true,
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(child: rail),
                    ),
                  ),
                ),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeLeft: !context.isRtl,
                    removeRight: context.isRtl,
                    child: _Section(
                      loader: sections[selectedIndex].tiles(context),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final Future<List<SettingsTile>> loader;

  const _Section({required this.loader});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SettingsTile>>(
      future: loader,
      builder: (context, snapshot) {
        final tiles = snapshot.data;
        if (tiles == null) return const SizedBox();

        return SettingsListView(
          key: ValueKey(loader),
          children: tiles.map((v) => v.build(context)).toList(),
        );
      },
    );
  }
}

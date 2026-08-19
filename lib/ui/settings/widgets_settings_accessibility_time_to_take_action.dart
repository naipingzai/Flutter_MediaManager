import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/services/accessibility_service.dart';
import 'package:flutter_media_view/ui/common/view.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_common_tiles.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

class TimeToTakeActionTile extends StatefulWidget {
  const TimeToTakeActionTile({super.key});

  static const List<String> settingKeys = [SettingKeys.timeToTakeActionKey];

  @override
  State<TimeToTakeActionTile> createState() => _TimeToTakeActionTileState();
}

class _TimeToTakeActionTileState extends State<TimeToTakeActionTile> {
  late Future<bool> _hasSystemOptionLoader;

  @override
  void initState() {
    super.initState();
    _hasSystemOptionLoader = AccessibilityService.hasRecommendedTimeouts();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasSystemOptionLoader,
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) return const SizedBox();
        const values = AccessibilityTimeout.values;
        final hasSystemOption = snapshot.data!;
        final optionValues = hasSystemOption ? values : values.where((v) => v != AccessibilityTimeout.system).toList();

        return SettingsSelectionListTile<AccessibilityTimeout>(
          values: optionValues,
          getName: (context, v) => v.getName(context),
          selector: (context, s) => s.timeToTakeAction,
          onSelection: (v) => settings.timeToTakeAction = v,
          tileTitle: (context) => context.l10n.settingsTimeToTakeActionTile,
        );
      },
    );
  }
}

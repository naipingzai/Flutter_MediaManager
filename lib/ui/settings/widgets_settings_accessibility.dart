import 'dart:async';

import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/theme/colors.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/view.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/settings/widgets_accessibility_time_to_take_action.dart';
import 'package:flutter_media_view/ui/settings/widgets_common_tile_leading.dart';
import 'package:flutter_media_view/ui/settings/widgets_common_tiles.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_definition.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AccessibilitySection extends SettingsSection {
  @override
  String get key => 'accessibility';

  @override
  Widget icon(BuildContext context) => SettingsTileLeading(
    icon: AIcons.accessibility,
    color: context.select<FmvColorsData, Color>((v) => v.accessibility),
  );

  @override
  String title(BuildContext context) => context.l10n.settingsAccessibilitySectionTitle;

  @override
  Future<List<SettingsTile>> tiles(BuildContext context) => Future.value([
    if (!settings.useTvLayout) SettingsTileAccessibilityShowPinchGestureAlternatives(),
    SettingsTileAccessibilityAnimations(),
    SettingsTileAccessibilityTimeToTakeAction(),
  ]);
}

class SettingsTileAccessibilityShowPinchGestureAlternatives extends SettingsTile {
  @override
  List<String> get settingKeys => [SettingKeys.showPinchGestureAlternativesKey];

  @override
  String title(BuildContext context) => context.l10n.settingsAccessibilityShowPinchGestureAlternatives;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.showPinchGestureAlternatives,
    onChanged: (v) => settings.showPinchGestureAlternatives = v,
    title: title,
  );
}

class SettingsTileAccessibilityAnimations extends SettingsTile {
  @override
  List<String> get settingKeys => [SettingKeys.accessibilityAnimationsKey];

  @override
  String title(BuildContext context) => context.l10n.settingsRemoveAnimationsTile;

  @override
  Widget build(BuildContext context) => SettingsSelectionListTile<AccessibilityAnimations>(
    values: AccessibilityAnimations.values,
    getName: (context, v) => v.getName(context),
    selector: (context, s) => s.accessibilityAnimations,
    onSelection: (v) => settings.accessibilityAnimations = v,
    tileTitle: title,
    dialogTitle: context.l10n.settingsRemoveAnimationsDialogTitle,
  );
}

class SettingsTileAccessibilityTimeToTakeAction extends SettingsTile {
  @override
  List<String> get settingKeys => TimeToTakeActionTile.settingKeys;

  @override
  String title(BuildContext context) => context.l10n.settingsTimeToTakeActionTile;

  @override
  Widget build(BuildContext context) => const TimeToTakeActionTile();
}

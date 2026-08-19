import 'dart:async';

import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/function/source/collection_source.dart';
import 'package:fmv/function/model/function_vaults.dart';
import 'package:fmv/function/common/services.dart';
import 'package:fmv/ui/theme/colors.dart';
import 'package:fmv/ui/theme/icons.dart';
import 'package:fmv/ui/collection/entry_set_action_delegate.dart';
import 'package:fmv/ui/common/actions/mixins_permission_aware.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv/ui/common/dialogs_fmv_confirmation_dialog.dart';
import 'package:fmv/ui/common/dialogs_fmv_dialog.dart';
import 'package:fmv/ui/settings/common/tile_leading.dart';
import 'package:fmv/ui/settings/common/tiles.dart';
import 'package:fmv/ui/settings/privacy/access_grants_page.dart';
import 'package:fmv/ui/settings/privacy/hidden_items_page.dart';
import 'package:fmv/ui/settings/privacy/permissions_tile.dart';
import 'package:fmv/ui/settings/definition.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PrivacySection extends SettingsSection {
  @override
  String get key => 'privacy';

  @override
  Widget icon(BuildContext context) => SettingsTileLeading(
    icon: AIcons.privacy,
    color: context.select<FmvColorsData, Color>((v) => v.privacy),
  );

  @override
  String title(BuildContext context) => context.l10n.settingsPrivacySectionTitle;

  @override
  Future<List<SettingsTile>> tiles(BuildContext context) async {
    return [
      SettingsTilePermissions(),
      SettingsTilePrivacyHiddenItems(),
      if (!settings.useTvLayout) SettingsTilePrivacyStorageAccess(),
      if (!settings.useTvLayout) SettingsTilePrivacyEnableBin(),
      SettingsTilePrivacySaveSearchHistory(),
      if (!settings.useTvLayout) SettingsTilePrivacyAutoExportSettings(),
    ];
  }
}

class SettingsTilePrivacyAutoExportSettings extends SettingsTile with PermissionAwareMixin {
  @override
  List<String> get settingKeys => [SettingKeys.autoExportPathKey];

  @override
  String title(BuildContext context) => context.l10n.settingsAutoExportSettings;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.autoExportPath != null,
    onChanged: (v) async {
      if (v) {
        if (!await checkSystemFilePickerEnabled(context)) return;

        final dirPath = await storageService.requestAnyDirectoryAccess();
        if (dirPath == null) return;

        settings.autoExportPath = dirPath;
      } else {
        settings.autoExportPath = null;
      }
    },
    title: title,
    subtitle: (_) => settings.autoExportPath,
  );
}

class SettingsTilePrivacySaveSearchHistory extends SettingsTile {
  @override
  List<String> get settingKeys => [SettingKeys.saveSearchHistoryKey];

  @override
  String title(BuildContext context) => context.l10n.settingsSaveSearchHistory;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.saveSearchHistory,
    onChanged: (v) {
      settings.saveSearchHistory = v;
      if (!v) {
        settings.searchHistory = [];
      }
    },
    title: title,
  );
}

class SettingsTilePrivacyEnableBin extends SettingsTile {
  @override
  List<String> get settingKeys => [SettingKeys.enableBinKey];

  @override
  String title(BuildContext context) => context.l10n.settingsEnableBin;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.enableBin,
    onChanged: (v) => setBinUsage(context, v),
    title: title,
    subtitle: (context) => context.l10n.settingsEnableBinSubtitle,
  );

  static Future<bool> setBinUsage(BuildContext context, bool enabled) async {
    final l10n = context.l10n;
    if (!enabled) {
      if (vaults.all.any((v) => v.useBin)) {
        await showWarningDialog(
          context: context,
          message: l10n.vaultBinUsageDialogMessage,
        );
        return false;
      }

      final source = context.read<CollectionSource>();
      final trashedEntries = source.trashedEntries;
      if (trashedEntries.isNotEmpty) {
        if (!await showConfirmationDialog(
          context: context,
          message: l10n.settingsDisablingBinWarningDialogMessage,
          ok: l10n.applyButtonLabel,
        )) {
          return false;
        }

        // delete forever trashed items
        await EntrySetActionDelegate().doDelete(
          context: context,
          entries: trashedEntries,
          enableBin: false,
        );

        // in case of failure or cancellation
        if (source.trashedEntries.isNotEmpty) return false;
      }

      settings.searchHistory = [];
    }

    settings.enableBin = enabled;
    return true;
  }
}

class SettingsTilePrivacyHiddenItems extends SettingsTile {
  @override
  List<String> get settingKeys => HiddenItemsPage.settingKeys;

  @override
  String title(BuildContext context) => context.l10n.settingsHiddenItemsTile;

  @override
  Widget build(BuildContext context) => SettingsSubPageTile(
    title: title,
    routeName: HiddenItemsPage.routeName,
    builder: (context) => const HiddenItemsPage(),
  );
}

class SettingsTilePrivacyStorageAccess extends SettingsTile {
  @override
  List<String> get settingKeys => []; // no editable settings

  @override
  String title(BuildContext context) => context.l10n.settingsStorageAccessTile;

  @override
  Widget build(BuildContext context) => SettingsSubPageTile(
    title: title,
    routeName: StorageAccessPage.routeName,
    builder: (context) => const StorageAccessPage(),
  );
}

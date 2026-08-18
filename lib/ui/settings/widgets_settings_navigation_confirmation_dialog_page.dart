import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/common/common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/settings/widgets_settings_common_tiles.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

class ConfirmationDialogPage extends StatelessWidget {
  static const routeName = '/settings/navigation_confirmation';

  static const List<String> settingKeys = [
    SettingKeys.confirmMoveUndatedItemsKey,
    SettingKeys.confirmMoveToBinKey,
    SettingKeys.confirmDeleteForeverKey,
    SettingKeys.confirmAfterMoveToBinKey,
    SettingKeys.confirmCreateVaultKey,
  ];

  const ConfirmationDialogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FmvScaffold(
      appBar: AppBar(
        title: Text(l10n.settingsConfirmationDialogTitle),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            SettingsSwitchListTile(
              selector: (context, s) => s.confirmMoveUndatedItems,
              onChanged: (v) => settings.confirmMoveUndatedItems = v,
              title: (_) => l10n.settingsConfirmationBeforeMoveUndatedItems,
            ),
            SettingsSwitchListTile(
              selector: (context, s) => s.confirmMoveToBin,
              onChanged: (v) => settings.confirmMoveToBin = v,
              title: (_) => l10n.settingsConfirmationBeforeMoveToBinItems,
            ),
            SettingsSwitchListTile(
              selector: (context, s) => s.confirmDeleteForever,
              onChanged: (v) => settings.confirmDeleteForever = v,
              title: (_) => l10n.settingsConfirmationBeforeDeleteItems,
            ),
            const Divider(height: 32),
            SettingsSwitchListTile(
              selector: (context, s) => s.confirmAfterMoveToBin,
              onChanged: (v) => settings.confirmAfterMoveToBin = v,
              title: (_) => l10n.settingsConfirmationAfterMoveToBinItems,
            ),
            const Divider(height: 32),
            SettingsSwitchListTile(
              selector: (context, s) => s.confirmCreateVault,
              onChanged: (v) => settings.confirmCreateVault = v,
              title: (_) => l10n.settingsConfirmationVaultDataLoss,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:fmv/core/app_flavor.dart';
import 'package:fmv/function/device/function_device.dart';
import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/ui/theme/icons.dart';
import 'package:fmv/ui/common/basic/basic_scaffold.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv/ui/settings/common/tiles.dart';
import 'package:fmv/ui/settings/privacy/permissions_manage_media.dart';
import 'package:fmv/ui/settings/privacy/permissions_notification.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PermissionsPage extends StatelessWidget {
  static const routeName = '/settings/privacy/permissions';

  static const List<String> settingKeys = [
    SettingKeys.isInstalledAppAccessAllowedKey,
    SettingKeys.isErrorReportingAllowedKey,
  ];

  const PermissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canEnableErrorReporting = context.select<AppFlavor, bool>((v) => v.canEnableErrorReporting);
    return FmvScaffold(
      appBar: AppBar(
        title: Text(l10n.settingsPermissionsPageTitle),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            SettingsSwitchListTile(
              selector: (context, s) => s.isInstalledAppAccessAllowed,
              onChanged: (v) => settings.isInstalledAppAccessAllowed = v,
              leading: const Icon(AIcons.app),
              title: (context) => context.l10n.settingsAllowInstalledAppAccess,
              subtitle: (context) => context.l10n.settingsAllowInstalledAppAccessSubtitle,
            ),
            if (canEnableErrorReporting)
              SettingsSwitchListTile(
                selector: (context, s) => s.isErrorReportingAllowed,
                onChanged: (v) => settings.isErrorReportingAllowed = v,
                leading: const Icon(AIcons.bugReport),
                title: (context) => context.l10n.settingsAllowErrorReporting,
              ),
            const NotificationPermissionTile(),
            if (!settings.useTvLayout && device.canRequestMediaManagementPermission) const ManageMediaTile(),
          ],
        ),
      ),
    );
  }
}

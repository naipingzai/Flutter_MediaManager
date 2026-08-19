import 'dart:async';

import 'package:fmv/core/app_flavor.dart';
import 'package:fmv/function/device/function_device.dart';
import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/function/common/services.dart';
import 'package:fmv/ui/theme/icons.dart';
import 'package:fmv/ui/theme/text.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv/ui/settings/common/tiles.dart';
import 'package:fmv/ui/settings/privacy/permissions_page.dart';
import 'package:fmv/ui/settings/definition.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class SettingsTilePermissions extends SettingsTile {
  @override
  List<String> get settingKeys => PermissionsPage.settingKeys;

  @override
  String title(BuildContext context) => context.l10n.settingsPermissionsTile;

  @override
  Widget build(BuildContext context) => SettingsSubPageTile(
    title: title,
    subtitle: (context) => const SettingsTilePermissionsSubtitle(),
    routeName: PermissionsPage.routeName,
    builder: (context) => const PermissionsPage(),
  );
}

class SettingsTilePermissionsSubtitle extends StatefulWidget {
  const SettingsTilePermissionsSubtitle({super.key});

  @override
  State<SettingsTilePermissionsSubtitle> createState() => _SettingsTilePermissionsSubtitleState();
}

class _SettingsTilePermissionsSubtitleState extends State<SettingsTilePermissionsSubtitle> with WidgetsBindingObserver {
  late Future<bool> _isMediaManagementAllowedLoader;
  late Future<bool> _areNotificationsEnabledLoader;

  @override
  void initState() {
    super.initState();
    _initLoader();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initLoader() {
    _isMediaManagementAllowedLoader = deviceService.canManageMedia();
    _areNotificationsEnabledLoader = Permission.notification.status.then((v) => v == PermissionStatus.granted);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initLoader();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _areNotificationsEnabledLoader,
      builder: (context, notificationSnapshot) {
        final areNotificationsEnabled = notificationSnapshot.data ?? false;
        return FutureBuilder<bool>(
          future: _isMediaManagementAllowedLoader,
          builder: (context, mediaManagementSnapshot) {
            final isMediaManagementAllowed = mediaManagementSnapshot.data ?? false;

            final permissions = <(IconData, bool)>[];
            permissions.add((AIcons.app, context.select<Settings, bool>((s) => s.isInstalledAppAccessAllowed)));
            if (context.select<AppFlavor, bool>((v) => v.canEnableErrorReporting)) {
              permissions.add((AIcons.bugReport, context.select<Settings, bool>((s) => s.isErrorReportingAllowed)));
            }
            permissions.add((AIcons.notifications, areNotificationsEnabled));
            if (!settings.useTvLayout && device.canRequestMediaManagementPermission) {
              permissions.add((AIcons.allCollection, isMediaManagementAllowed));
            }

            final theme = Theme.of(context);
            final subtitleTextStyle =
                theme.listTileTheme.subtitleTextStyle ??
                theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                );
            return IconTheme.merge(
              data: IconThemeData(
                size: 18,
                color: subtitleTextStyle.color,
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    ...(permissions
                        .expand((v) {
                          final (icon, enabled) = v;
                          return [
                            const TextSpan(text: AText.separator),
                            WidgetSpan(
                              child: Opacity(
                                opacity: enabled ? 1 : SettingsSwitchListTile.disabledOpacity,
                                child: Icon(icon),
                              ),
                              alignment: PlaceholderAlignment.middle,
                            ),
                          ];
                        })
                        .skip(1)),
                  ],
                ),
                style: subtitleTextStyle,
              ),
            );
          },
        );
      },
    );
  }
}

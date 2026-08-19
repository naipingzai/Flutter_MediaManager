import 'package:flutter_media_view/ui/theme/colors.dart';
import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view/ui/settings/common_tiles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingSwitchTrailingIcon extends StatelessWidget {
  final IconData icon;
  final bool disabled;

  const SettingSwitchTrailingIcon({
    super.key,
    required this.icon,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Switch width (`_kSwitchWidth`) + tile content padding
      padding: const EdgeInsetsDirectional.only(end: 59 + 16),
      child: AnimatedSwitcher(
        duration: context.read<DurationsData>().iconAnimation,
        child: Icon(
          icon,
          key: key,
          size: getIconSize(context),
          color: getIconColor(context).withValues(alpha: disabled ? SettingsSwitchListTile.disabledOpacity : 1),
        ),
      ),
    );
  }

  static double getIconSize(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return textScaler.scale(IconTheme.of(context).size!);
  }

  static Color getIconColor(BuildContext context) => context.select<FmvColorsData, Color>((v) => v.neutral);
}

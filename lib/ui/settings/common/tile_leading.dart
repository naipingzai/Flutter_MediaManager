import 'package:fmv/ui/theme/durations.dart';
import 'package:fmv/ui/theme/styles.dart';
import 'package:fmv/ui/theme/themes.dart';
import 'package:fmv/ui/common/extensions_theme.dart';
import 'package:fmv/ui/filter/identity_fmv_filter_chip.dart';
import 'package:decorated_icon/decorated_icon.dart';
import 'package:flutter/material.dart';

class SettingsTileLeading extends StatelessWidget {
  final IconData icon;
  final Color color;

  const SettingsTileLeading({
    super.key,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Themes.firstLayerColor(context),
        border: Border.fromBorderSide(
          BorderSide(
            color: color,
            width: FmvFilterChip.outlineWidth,
          ),
        ),
        shape: BoxShape.circle,
      ),
      duration: ADurations.themeColorModeAnimation,
      child: DecoratedIcon(
        icon,
        size: 18,
        color: DefaultTextStyle.of(context).style.color,
        shadows: Theme.of(context).isDark ? AStyles.embossShadows : null,
      ),
    );
  }
}

import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/ui/theme/icons.dart';
import 'package:fmv/ui/common/basic/basic_popup_menu_row.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MapItemTrackToggler extends StatelessWidget {
  final bool isMenuItem;
  final VoidCallback? onPressed;

  const MapItemTrackToggler({
    super.key,
    this.isMenuItem = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = context.select<Settings, bool>((v) => v.mapShowItemTracks);
    final icon = Icon(enabled ? AIcons.routeOff : AIcons.route);
    final text = enabled ? context.l10n.mapHideItemTracks : context.l10n.mapShowItemTracks;
    return isMenuItem
        ? MenuRow(
            text: text,
            icon: icon,
          )
        : IconButton(
            icon: icon,
            onPressed: onPressed,
            tooltip: text,
          );
  }
}

import 'package:flutter_media_view/ui/theme/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_basic_font_size_icon_theme.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter/material.dart';

class DrawerEditorBanner extends StatelessWidget {
  const DrawerEditorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const FontSizeIconTheme(child: Icon(AIcons.info)),
          const SizedBox(width: 16),
          Expanded(child: Text(context.l10n.settingsNavigationDrawerBanner)),
        ],
      ),
    );
  }
}

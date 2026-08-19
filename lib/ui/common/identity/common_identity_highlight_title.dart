import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/locale/locales.dart';
import 'package:flutter_media_view/ui/theme/colors.dart';
import 'package:flutter_media_view/ui/theme/themes.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_text_outlined.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/common_extensions_theme.dart';
import 'package:flutter_media_view/ui/common/common_fx_highlight_decoration.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HighlightTitle extends StatelessWidget {
  final String title;
  final Color? color;
  final double fontSize;
  final bool enabled;
  final bool showHighlight;

  const HighlightTitle({
    super.key,
    required this.title,
    this.color,
    this.fontSize = 18,
    this.enabled = true,
    this.showHighlight = true,
  });

  static const disabledColor = Colors.grey;

  static List<Shadow> shadows(BuildContext context) => [
    Shadow(
      color: Theme.of(context).isDark ? Colors.black : Colors.white,
      offset: const Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      shadows: shadows(context),
      fontSize: fontSize,
      letterSpacing: canHaveLetterSpacing(context.localeName) ? 1 : 0,
      fontFeatures: const [FontFeature.enable('smcp')],
    );

    final colors = context.watch<FmvColorsData>();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: showHighlight && context.select<Settings, bool>((v) => v.themeColorMode == FmvThemeColorMode.polychrome)
            ? HighlightDecoration(
                color: enabled ? color ?? colors.fromString(title) : disabledColor,
              )
            : null,
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        child: OutlinedText(
          textSpans: [
            TextSpan(
              text: title,
              style: style,
            ),
          ],
          outlineColor: Themes.firstLayerColor(context),
          softWrap: false,
          overflow: TextOverflow.fade,
          maxLines: 1,
        ),
      ),
    );
  }
}

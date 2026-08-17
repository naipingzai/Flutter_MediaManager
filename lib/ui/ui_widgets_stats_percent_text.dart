import 'package:flutter_media_view/function/function_settings.dart';
import 'package:flutter_media_view/ui/ui_theme_styles.dart';
import 'package:flutter_media_view/ui/ui_theme_themes.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_basic_text_outlined.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_extensions_theme.dart';
import 'package:flutter/material.dart';

class LinearPercentIndicatorText extends StatelessWidget {
  final double percent;

  const LinearPercentIndicatorText({
    super.key,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final percentFormatter = settings.avesLocale.percentNumberFormat();

    return OutlinedText(
      textSpans: [
        TextSpan(
          text: percentFormatter.format(percent),
          style: TextStyle(
            shadows: Theme.of(context).isDark ? AStyles.embossShadows : null,
          ),
        ),
      ],
      outlineColor: Themes.firstLayerColor(context),
    );
  }
}

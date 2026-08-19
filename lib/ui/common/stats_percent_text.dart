import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/theme/styles.dart';
import 'package:flutter_media_view/ui/theme/themes.dart';
import 'package:flutter_media_view/ui/common/basic/basic_text_outlined.dart';
import 'package:flutter_media_view/ui/common/extensions_theme.dart';
import 'package:flutter/material.dart';

class LinearPercentIndicatorText extends StatelessWidget {
  final double percent;

  const LinearPercentIndicatorText({
    super.key,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final percentFormatter = settings.fmvLocale.percentNumberFormat();

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

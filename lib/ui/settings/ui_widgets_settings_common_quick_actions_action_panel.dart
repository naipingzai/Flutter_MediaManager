import 'package:flutter_media_view/ui/theme/ui_theme_durations.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_themes.dart';
import 'package:flutter/material.dart';

class ActionPanel extends StatelessWidget {
  final bool highlight;
  final Widget child;

  const ActionPanel({
    super.key,
    this.highlight = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight ? theme.colorScheme.primary : Color.alphaBlend(theme.colorScheme.surfaceTint.withValues(alpha: .2), Themes.secondLayerColor(context));
    return AnimatedContainer(
      foregroundDecoration: BoxDecoration(
        color: color.withValues(alpha: .2),
        border: Border.fromBorderSide(
          BorderSide(
            color: color,
            width: highlight ? 2 : 1,
          ),
        ),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      margin: const EdgeInsets.all(16),
      duration: ADurations.quickActionHighlightAnimation,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: child,
      ),
    );
  }
}

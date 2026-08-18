import 'package:flutter_media_view/function/entry/function_entry.dart';
import 'package:flutter_media_view/function/function_selection.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_durations.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_text.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_basic_text_animated_diff.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_identity_buttons_overlay_button.dart';
import 'package:flutter_media_view/ui/viewer/ui_widgets_viewer_overlay_bottom.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SelectionButton extends StatelessWidget {
  final AvesEntry mainEntry;
  final Animation<double> scale;

  static const double padding = 8;

  const SelectionButton({
    super.key,
    required this.mainEntry,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selection = context.read<Selection<AvesEntry>>();
    final duration = context.select<DurationsData, Duration>((v) => v.formTransition);
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(left: padding, right: padding, bottom: padding),
        child: Row(
          mainAxisSize: .min,
          textDirection: ViewerBottomOverlay.actionsDirection,
          children: [
            const Spacer(),
            ScalingOverlayTextButton(
              scale: scale,
              onPressed: () => selection.toggleSelection(mainEntry),
              child: Selector<Selection<AvesEntry>?, int>(
                selector: (context, selection) => selection?.selectedItemCount ?? 0,
                builder: (context, count, child) {
                  return Row(
                    mainAxisSize: .min,
                    textDirection: ViewerBottomOverlay.actionsDirection,
                    children: [
                      AnimatedDiffText(
                        count == 0 ? l10n.collectionSelectPageTitle : l10n.itemCount(count),
                        duration: duration,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(AText.separator),
                      ),
                      Selector<Selection<AvesEntry>, bool>(
                        selector: (context, selection) => selection.isSelected({mainEntry}),
                        builder: (context, isSelected, child) {
                          return AnimatedSwitcher(
                            duration: duration,
                            switchInCurve: Curves.easeOutBack,
                            switchOutCurve: Curves.easeOutBack,
                            transitionBuilder: (child, animation) => ScaleTransition(
                              scale: animation,
                              child: child,
                            ),
                            child: Icon(
                              isSelected ? AIcons.selected : AIcons.unselected,
                              key: ValueKey(isSelected),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

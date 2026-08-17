import 'package:flutter_media_view/function/function_entry.dart';
import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view/ui/view/view.dart';
import 'package:flutter_media_view/ui/widgets/common/basic/multi_cross_fader.dart';
import 'package:flutter_media_view/ui/widgets/common/extensions/build_context.dart';
import 'package:flutter_media_view/ui/widgets/common/identity/buttons/overlay_button.dart';
import 'package:flutter_media_view/ui/widgets/editor/transform/control_panel.dart';
import 'package:flutter_media_view/ui/widgets/editor/transform/controller.dart';
import 'package:flutter_media_view/ui/widgets/viewer/overlay/bottom/viewer_buttons.dart';
import 'package:aves_magnifier/aves_magnifier.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorControlPanel extends StatelessWidget {
  final AvesEntry entry;
  final ValueNotifier<EditorAction?> actionNotifier;

  static const padding = ViewerButtonRowContent.padding;

  const EditorControlPanel({
    super.key,
    required this.entry,
    required this.actionNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: actionNotifier.value == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        _cancelAction(context);
      },
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: TooltipTheme(
          data: TooltipTheme.of(context).copyWith(
            preferBelow: false,
          ),
          child: ValueListenableBuilder<EditorAction?>(
            valueListenable: actionNotifier,
            builder: (context, action, child) {
              return MultiCrossFader(
                duration: context.select<DurationsData, Duration>((v) => v.formTransition),
                alignment: Alignment.bottomCenter,
                layoutBuilder: (topChild, topChildKey, bottomChild, bottomChildKey) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned(
                        key: bottomChildKey,
                        left: 0.0,
                        bottom: 0.0,
                        right: 0.0,
                        child: bottomChild,
                      ),
                      Positioned(
                        key: topChildKey,
                        child: topChild,
                      ),
                    ],
                  );
                },
                child: BackdropGroup(
                  child: action == null
                      ? _TopLevelPanel(
                          actionNotifier: actionNotifier,
                        )
                      : _buildActionPanel(context, action),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActionPanel(BuildContext context, EditorAction action) {
    switch (action) {
      case .transform:
        return TransformControlPanel(
          entry: entry,
          onCancel: () => _cancelAction(context),
          onApply: (transformation) => _applyAction(context),
        );
    }
  }

  void _cancelAction(BuildContext context) {
    actionNotifier.value = null;
    context.read<AvesMagnifierController>().reset();
    context.read<TransformController>().reset();
  }

  void _applyAction(BuildContext context) {
    actionNotifier.value = null;
    context.read<TransformController>().reset();
  }
}

class _TopLevelPanel extends StatelessWidget {
  final ValueNotifier<EditorAction?> actionNotifier;

  static const padding = ViewerButtonRowContent.padding;
  static const actions = [
    EditorAction.transform,
  ];

  const _TopLevelPanel({
    required this.actionNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      children: [
        Row(
          mainAxisSize: .min,
          children: [
            ...actions.map(
              (action) => Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: padding / 2),
                child: OverlayButton(
                  child: IconButton(
                    icon: action.getIcon(),
                    onPressed: () => actionNotifier.value = action,
                    tooltip: action.getText(context),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: padding),
        Row(
          children: [
            const OverlayButton(
              child: CloseButton(),
            ),
            const Spacer(),
            OverlayTextButton(
              onPressed: () {},
              child: Text(context.l10n.saveCopyButtonLabel),
            ),
          ],
        ),
      ],
    );
  }
}

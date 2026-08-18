import 'package:flutter_media_view/ui/common/view.dart';
import 'package:flutter_media_view/ui/common/common_action_controls_quick_choosers_common_button.dart';
import 'package:flutter_media_view/ui/common/common_action_controls_quick_choosers_rate_chooser.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

class RateButton extends ChooserQuickButton<int> {
  const RateButton({
    super.key,
    required super.blurred,
    super.onChooserValue,
    super.focusNode,
    required super.onPressed,
  });

  @override
  State<RateButton> createState() => _RateButtonState();
}

class _RateButtonState extends ChooserQuickButtonState<RateButton, int> {
  static const _action = EntryAction.editRating;

  @override
  Widget get icon => _action.getIcon();

  @override
  String get tooltip => _action.getText(context);

  @override
  int? get defaultValue => 3;

  @override
  Widget buildChooser(Animation<double> animation, PopupMenuPosition chooserPosition) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: animation,
        alignment: chooserPosition == PopupMenuPosition.over ? Alignment.bottomCenter : Alignment.topCenter,
        child: RateQuickChooser(
          blurred: widget.blurred,
          valueNotifier: chooserValueNotifier,
          pointerGlobalPosition: pointerGlobalPosition,
        ),
      ),
    );
  }
}

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_multipage.dart';
import 'package:flutter_media_view/ui/common/view.dart';
import 'package:flutter_media_view/ui/common/actions/common_action_controls_quick_choosers_common_button.dart';
import 'package:flutter_media_view/ui/common/actions/common_action_controls_quick_choosers_share_chooser.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

class ShareButton extends ChooserQuickButton<ShareAction> {
  final Set<FmvEntry> entries;

  const ShareButton({
    super.key,
    required super.blurred,
    required this.entries,
    super.onChooserValue,
    super.focusNode,
    required super.onPressed,
  });

  @override
  State<ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends ChooserQuickButtonState<ShareButton, ShareAction> {
  EntryAction get action => EntryAction.share;

  @override
  Widget get icon => action.getIcon();

  @override
  String get tooltip => action.getText(context);

  @override
  bool get hasChooser => super.hasChooser && options.isNotEmpty;

  List<ShareAction> get options => [
    if (widget.entries.any((entry) => entry.isMotionPhoto)) ...[
      ShareAction.imageOnly,
      ShareAction.videoOnly,
    ],
  ];

  @override
  Widget buildChooser(Animation<double> animation, PopupMenuPosition chooserPosition) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: animation,
        alignment: chooserPosition == PopupMenuPosition.over ? Alignment.bottomCenter : Alignment.topCenter,
        child: ShareQuickChooser(
          valueNotifier: chooserValueNotifier,
          options: options,
          blurred: widget.blurred,
          chooserPosition: chooserPosition,
          pointerGlobalPosition: pointerGlobalPosition,
        ),
      ),
    );
  }
}

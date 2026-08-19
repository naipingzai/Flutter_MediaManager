import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

import 'package:flutter_media_view/ui/common/dialogs_fmv_dialog.dart';

Future<bool> showConfirmationDialog({
  required BuildContext context,
  required String message,
  String? ok,
  String? cancel,
}) async {
  final confirmed = await showFmvDialog<bool>(
    context: context,
    builder: (context) => FmvMessageDialog(
      message: message,
      actions: [
        CancelButton<bool>(text: cancel, result: false),
        OkButton<bool>(text: ok, result: true),
      ],
    ),
    routeSettings: const RouteSettings(name: FmvDialog.confirmationRouteName),
  );
  return confirmed ?? false;
}

Future<bool> showSkippableConfirmationDialog({
  required BuildContext context,
  required ConfirmationDialog type,
  String? message,
  ConfirmationDialogDelegate? delegate,
  required String confirmationButtonLabel,
}) async {
  if (!_shouldConfirm(type)) return true;

  assert((message != null) ^ (delegate != null));
  final effectiveDelegate = delegate ?? MessageConfirmationDialogDelegate(message!);
  final confirmed = await showFmvDialog<bool>(
    context: context,
    builder: (context) => _SkippableConfirmationDialog(
      type: type,
      delegate: effectiveDelegate,
      confirmationButtonLabel: confirmationButtonLabel,
    ),
    routeSettings: const RouteSettings(name: _SkippableConfirmationDialog.routeName),
  );
  if (confirmed == null) return false;

  if (confirmed) {
    effectiveDelegate.apply();
  }
  return confirmed;
}

bool _shouldConfirm(ConfirmationDialog type) {
  switch (type) {
    case .createVault:
      return settings.confirmCreateVault;
    case .deleteForever:
      return settings.confirmDeleteForever;
    case .moveToBin:
      return settings.confirmMoveToBin;
    case .moveUndatedItems:
      return settings.confirmMoveUndatedItems;
  }
}

void _skipConfirmation(ConfirmationDialog type) {
  switch (type) {
    case .createVault:
      settings.confirmCreateVault = false;
    case .deleteForever:
      settings.confirmDeleteForever = false;
    case .moveToBin:
      settings.confirmMoveToBin = false;
    case .moveUndatedItems:
      settings.confirmMoveUndatedItems = false;
  }
}

abstract class ConfirmationDialogDelegate {
  List<Widget> build(BuildContext context);

  void apply() {}
}

class MessageConfirmationDialogDelegate extends ConfirmationDialogDelegate {
  final String message;

  MessageConfirmationDialogDelegate(this.message);

  @override
  List<Widget> build(BuildContext context) => [
    Padding(
      padding: const EdgeInsets.all(16) + const EdgeInsets.only(top: 8),
      child: Text(message),
    ),
  ];
}

class _SkippableConfirmationDialog extends StatefulWidget {
  static const routeName = '/dialog/skippable_confirmation';

  final ConfirmationDialog type;
  final ConfirmationDialogDelegate delegate;
  final String confirmationButtonLabel;

  const _SkippableConfirmationDialog({
    required this.type,
    required this.delegate,
    required this.confirmationButtonLabel,
  });

  @override
  State<_SkippableConfirmationDialog> createState() => _SkippableConfirmationDialogState();
}

class _SkippableConfirmationDialogState extends State<_SkippableConfirmationDialog> {
  final ValueNotifier<bool> _skipNotifier = ValueNotifier(false);

  @override
  void dispose() {
    _skipNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FmvDialog(
      scrollableContent: [
        ...widget.delegate.build(context),
        ValueListenableBuilder<bool>(
          valueListenable: _skipNotifier,
          builder: (context, flag, child) => SwitchListTile(
            value: flag,
            onChanged: (v) => _skipNotifier.value = v,
            title: Text(context.l10n.doNotAskAgain),
          ),
        ),
      ],
      actions: [
        const CancelButton(),
        TextButton(
          onPressed: () {
            if (_skipNotifier.value) {
              _skipConfirmation(widget.type);
            }
            Navigator.maybeOf(context)?.pop<bool>(true);
          },
          child: Text(widget.confirmationButtonLabel),
        ),
      ],
    );
  }
}

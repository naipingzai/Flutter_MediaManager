import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/dialogs_fmv_dialog.dart';
import 'package:flutter/material.dart';

class PasswordDialog extends StatefulWidget {
  static const routeName = '/dialog/password';

  final bool needConfirmation;

  const PasswordDialog({
    super.key,
    required this.needConfirmation,
  });

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _confirming = false;
  String? _firstPassword;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FmvDialog(
      content: Column(
        mainAxisSize: .min,
        children: [
          Text(_confirming ? context.l10n.passwordDialogConfirm : context.l10n.passwordDialogEnter),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              obscureText: true,
              onSubmitted: _submit,
              autofillHints: const [AutofillHints.password],
            ),
          ),
        ],
      ),
    );
  }

  void _submit(String password) {
    if (widget.needConfirmation) {
      if (_confirming) {
        final match = _firstPassword == password;
        Navigator.maybeOf(context)?.pop<String>(match ? password : null);
        if (!match) {
          showWarningDialog(
            context: context,
            message: context.l10n.genericFailureFeedback,
          );
        }
      } else {
        _firstPassword = password;
        _controller.clear();
        setState(() => _confirming = true);
        WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
      }
    } else {
      Navigator.maybeOf(context)?.pop<String>(password);
    }
  }
}

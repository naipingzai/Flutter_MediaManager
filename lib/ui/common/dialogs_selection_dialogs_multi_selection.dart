import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/dialogs_fmv_dialog.dart';
import 'package:flutter_media_view/ui/common/dialogs_selection_dialogs_common.dart';
import 'package:flutter/material.dart';

class FmvMultiSelectionDialog<T> extends StatefulWidget {
  static const routeName = '/dialog/multi_selection';

  final Set<T> initialValue;
  final Map<T, String> options;
  final TextBuilder<T>? optionSubtitleBuilder;
  final String? title, message;
  final bool? dense;

  const FmvMultiSelectionDialog({
    super.key,
    required this.initialValue,
    required this.options,
    this.optionSubtitleBuilder,
    this.title,
    this.message,
    this.dense,
  });

  @override
  State<FmvMultiSelectionDialog<T>> createState() => _AvesMultiSelectionDialogState<T>();
}

class _AvesMultiSelectionDialogState<T> extends State<FmvMultiSelectionDialog<T>> {
  late Set<T> _selectedValues;

  @override
  void initState() {
    super.initState();
    _selectedValues = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final message = widget.message;
    final verticalPadding = (title == null && message == null) ? FmvDialog.cornerRadius.y / 2 : .0;
    return FmvDialog(
      title: title,
      scrollableContent: [
        if (verticalPadding != 0) SizedBox(height: verticalPadding),
        if (message != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(message),
          ),
        ...widget.options.entries.map((kv) {
          final value = kv.key;
          final title = kv.value;
          final subtitle = widget.optionSubtitleBuilder?.call(value);
          return SwitchListTile(
            value: _selectedValues.contains(value),
            onChanged: (v) {
              if (v) {
                _selectedValues.add(value);
              } else {
                _selectedValues.remove(value);
              }
              setState(() {});
            },
            title: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(title),
            ),
            subtitle: subtitle != null
                ? Text(
                    subtitle,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  )
                : null,
            dense: widget.dense,
          );
        }),
        if (verticalPadding != 0) SizedBox(height: verticalPadding),
      ],
      actions: [
        const CancelButton(),
        TextButton(
          onPressed: () {
            final result = widget.options.keys.where(_selectedValues.contains).toList();
            return Navigator.maybeOf(context)?.pop<List<T>>(result);
          },
          child: Text(context.l10n.applyButtonLabel),
        ),
      ],
    );
  }
}

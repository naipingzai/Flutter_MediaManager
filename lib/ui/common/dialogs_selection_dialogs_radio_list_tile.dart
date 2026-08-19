import 'package:flutter_media_view/ui/common/basic/basic_list_tiles_reselectable_radio.dart';
import 'package:flutter_media_view/ui/common/dialogs_selection_dialogs_common.dart';
import 'package:flutter/material.dart';

class SelectionRadioListTile<T> extends StatelessWidget {
  final T value;
  final String title;
  final TextBuilder<T>? optionSubtitleBuilder;
  final bool? dense;
  final Widget? secondary;

  const SelectionRadioListTile({
    super.key,
    required this.value,
    required this.title,
    this.optionSubtitleBuilder,
    this.dense,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = optionSubtitleBuilder?.call(value);
    return ReselectableRadioListTile<T>(
      // key is expected by test driver
      key: Key('$value'),
      value: value,
      reselectable: true,
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              softWrap: false,
              overflow: TextOverflow.fade,
            )
          : null,
      dense: dense,
      secondary: secondary,
    );
  }
}

import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view/ui/common/dialogs_fmv_dialog.dart';
import 'package:flutter_media_view/ui/common/dialogs_selection_dialogs_single_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

Future<void> showSelectionDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required void Function(T value) onSelection,
}) async {
  final value = await showFmvDialog<T>(
    context: context,
    builder: builder,
    routeSettings: const RouteSettings(name: FmvSingleSelectionDialog.routeName),
  );
  // wait for the dialog to hide
  await Future.delayed(ADurations.dialogTransitionLoose * timeDilation);
  if (value != null) {
    onSelection(value);
  }
}

typedef TextBuilder<T> = String? Function(T value);

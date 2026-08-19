import 'package:fmv/function/entry/entry.dart';
import 'package:flutter/widgets.dart';

@immutable
class OpenViewerNotification extends Notification {
  final FmvEntry entry;

  const OpenViewerNotification(this.entry);
}

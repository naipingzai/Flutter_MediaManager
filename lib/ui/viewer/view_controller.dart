import 'package:fmv/function/entry/entry.dart';
import 'package:fmv/function/viewer/view_state.dart';
import 'package:fmv/ui/viewer/view_histogram.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:leak_tracker/leak_tracker.dart';

class ViewStateController with HistogramMixin {
  final FmvEntry entry;
  final ValueNotifier<ViewState> viewStateNotifier;
  final ValueNotifier<ImageProvider?> fullImageNotifier = ValueNotifier(null);

  ViewState get viewState => viewStateNotifier.value;

  ViewStateController({
    required this.entry,
    required this.viewStateNotifier,
  }) {
    if (kFlutterMemoryAllocationsEnabled) {
      LeakTracking.dispatchObjectCreated(
        library: 'fmv',
        className: '$ViewStateController',
        object: this,
      );
    }
  }

  void dispose() {
    if (kFlutterMemoryAllocationsEnabled) {
      LeakTracking.dispatchObjectDisposed(object: this);
    }
    viewStateNotifier.dispose();
    fullImageNotifier.dispose();
  }
}

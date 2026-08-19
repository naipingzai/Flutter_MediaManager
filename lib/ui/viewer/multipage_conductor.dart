import 'dart:async';

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/ui/viewer/multipage_controller.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:leak_tracker/leak_tracker.dart';

class MultiPageConductor {
  final List<MultiPageController> _controllers = [];

  static const maxControllerCount = 3;

  MultiPageConductor() {
    if (kFlutterMemoryAllocationsEnabled) {
      LeakTracking.dispatchObjectCreated(
        library: 'fmv',
        className: '$MultiPageConductor',
        object: this,
      );
    }
  }

  Future<void> dispose() async {
    if (kFlutterMemoryAllocationsEnabled) {
      LeakTracking.dispatchObjectDisposed(object: this);
    }
    await _disposeAll();
    _controllers.clear();
  }

  MultiPageController getOrCreateController(FmvEntry entry) {
    var controller = getController(entry);
    if (controller != null) {
      _controllers.remove(controller);
    } else {
      controller = MultiPageController(entry);
    }
    _controllers.insert(0, controller);
    while (_controllers.length > maxControllerCount) {
      _controllers.removeLast().dispose();
    }
    return controller;
  }

  MultiPageController? getController(FmvEntry entry) {
    return _controllers.firstWhereOrNull((c) => c.entry.uri == entry.uri && c.entry.pageId == entry.pageId);
  }

  Future<void> _applyToAll(void Function(MultiPageController controller) action) => Future.forEach<MultiPageController>(_controllers, action);

  Future<void> _disposeAll() => _applyToAll((controller) => controller.dispose());
}

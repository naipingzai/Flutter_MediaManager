import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/foundation.dart';

@immutable
class EntryAddedEvent {
  final Set<FmvEntry>? entries;

  const EntryAddedEvent([this.entries]);
}

@immutable
class EntryRemovedEvent {
  final Set<FmvEntry> entries;

  const EntryRemovedEvent(this.entries);
}

@immutable
class EntryMovedEvent {
  final MoveType type;
  final Set<FmvEntry> entries;

  const EntryMovedEvent(this.type, this.entries);
}

@immutable
class EntryRefreshedEvent {
  final Set<FmvEntry> entries;

  const EntryRefreshedEvent(this.entries);
}

@immutable
class FilterVisibilityChangedEvent {
  const FilterVisibilityChangedEvent();
}

@immutable
class ProgressEvent {
  final int done, total;

  const ProgressEvent({required this.done, required this.total});
}

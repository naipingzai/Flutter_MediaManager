import 'package:fmv/function/entry/entry.dart';
import 'package:fmv/function/filters/filters.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:fmv_video/flutter_media_view_video.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

@immutable
class LockViewNotification extends Notification {
  final bool locked;

  const LockViewNotification({required this.locked});
}

@immutable
class PopVisualNotification extends Notification {}

@immutable
class ShowImageNotification extends Notification {}

@immutable
class ShowInfoPageNotification extends Notification {}

@immutable
class ShowPreviousEntryNotification extends Notification {
  final bool animate;

  const ShowPreviousEntryNotification({required this.animate});
}

@immutable
class ShowNextEntryNotification extends Notification {
  final bool animate;

  const ShowNextEntryNotification({required this.animate});
}

@immutable
class ShowEntryNotification extends Notification {
  final bool animate;
  final int index;

  const ShowEntryNotification({
    required this.animate,
    required this.index,
  });
}

@immutable
class ShowPreviousVideoNotification extends Notification {}

@immutable
class ShowNextVideoNotification extends Notification {}

@immutable
class ToggleOverlayNotification extends Notification {
  final bool? visible;

  const ToggleOverlayNotification({this.visible});
}

@immutable
class TvShowLessInfoNotification extends Notification {}

@immutable
class TvShowMoreInfoNotification extends Notification {}

@immutable
class VideoActionNotification extends Notification {
  final FmvVideoController controller;
  final FmvEntry entry;
  final EntryAction action;

  const VideoActionNotification({
    required this.controller,
    required this.entry,
    required this.action,
  });
}

@immutable
class CastNotification extends Notification with Equatable {
  final bool enabled;

  @override
  List<Object?> get props => [enabled];

  const CastNotification(this.enabled);
}

@immutable
class SelectFilterNotification extends Notification with Equatable {
  final CollectionFilter filter;

  @override
  List<Object?> get props => [filter];

  const SelectFilterNotification(this.filter);
}

@immutable
class DecomposeFilterNotification extends Notification with Equatable {
  final CollectionFilter filter;

  @override
  List<Object?> get props => [filter];

  const DecomposeFilterNotification(this.filter);
}

@immutable
class EntryDeletedNotification extends Notification with Equatable {
  final Set<FmvEntry> entries;

  @override
  List<Object?> get props => [entries];

  const EntryDeletedNotification(this.entries);
}

@immutable
class EntryMovedNotification extends Notification with Equatable {
  final MoveType moveType;
  final Set<FmvEntry> entries;

  @override
  List<Object?> get props => [moveType, entries];

  const EntryMovedNotification(this.moveType, this.entries);
}

@immutable
class FullImageLoadedNotification extends Notification {
  final FmvEntry entry;
  final ImageProvider image;

  const FullImageLoadedNotification(this.entry, this.image);
}

@immutable
class PopupMenuOpenedNotification extends Notification {}

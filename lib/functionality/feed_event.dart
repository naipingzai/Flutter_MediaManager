part of 'feed_bloc.dart';

abstract class FeedEvent extends Equatable {
  const FeedEvent();
  @override
  List<Object?> get props => [];
}

class FeedLoadEvent extends FeedEvent {
  const FeedLoadEvent();
}

class FeedCreatePostEvent extends FeedEvent {
  final String content;
  final List<String> localMediaPaths;
  final String? videoPath;
  final String? audioPath;
  final List<String> tags;

  const FeedCreatePostEvent({
    required this.content,
    this.localMediaPaths = const [],
    this.videoPath,
    this.audioPath,
    this.tags = const [],
  });

  @override
  List<Object?> get props =>
      [content, localMediaPaths, videoPath, audioPath, tags];
}

/// 编辑动态
class FeedEditPostEvent extends FeedEvent {
  final String postId;
  final String content;
  final List<String> tags;
  final List<String> newLocalMediaPaths;
  final List<String> removedMediaFiles;
  final String? newVideoPath;
  final String? newAudioPath;

  const FeedEditPostEvent({
    required this.postId,
    required this.content,
    required this.tags,
    this.newLocalMediaPaths = const [],
    this.removedMediaFiles = const [],
    this.newVideoPath,
    this.newAudioPath,
  });

  @override
  List<Object?> get props =>
      [postId, content, tags, newLocalMediaPaths, removedMediaFiles];
}

class FeedDeletePostEvent extends FeedEvent {
  final String postId;
  const FeedDeletePostEvent(this.postId);
  @override
  List<Object?> get props => [postId];
}

class FeedSearchEvent extends FeedEvent {
  final String keyword;
  const FeedSearchEvent(this.keyword);
  @override
  List<Object?> get props => [keyword];
}

class FeedFilterByTagEvent extends FeedEvent {
  final String tag;
  const FeedFilterByTagEvent(this.tag);
  @override
  List<Object?> get props => [tag];
}

class FeedClearFilterEvent extends FeedEvent {
  const FeedClearFilterEvent();
}

class FeedColumnChangedEvent extends FeedEvent {
  final int columnCount;
  const FeedColumnChangedEvent(this.columnCount);
  @override
  List<Object?> get props => [columnCount];
}

/// 排序方式变更
class FeedSortChangedEvent extends FeedEvent {
  final FeedSortMode sortMode;
  const FeedSortChangedEvent(this.sortMode);
  @override
  List<Object?> get props => [sortMode];
}

/// 日期范围筛选
class FeedDateFilterEvent extends FeedEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  const FeedDateFilterEvent({this.startDate, this.endDate});
  @override
  List<Object?> get props => [startDate, endDate];
}

/// 后台同步完成后刷新 UI
class FeedRefreshEvent extends FeedEvent {
  const FeedRefreshEvent();
  @override
  List<Object?> get props => [];
}

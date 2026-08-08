part of 'feed_bloc.dart';

enum FeedStatus {
  initial,
  loading,
  loaded,
  syncing,
  publishing, // 正在发布动态（含上传文件 + 写 data.json）
  editing, // 正在编辑动态
  error,
}

/// 排序模式
enum FeedSortMode {
  newest, // 最新优先（默认）
  oldest, // 最早优先
  contentAsc, // 内容 A-Z
  contentDesc, // 内容 Z-A
  mediaCountDesc, // 媒体数多的优先
}

class FeedState extends Equatable {
  final FeedStatus status;
  final List<Post> posts;
  final List<Post> filteredPosts;
  final int columnCount;
  final String? searchKeyword;
  final String? selectedTag;
  final String? errorMessage;
  final String? mediaBaseUrl; // WebDAV 媒体文件基础 URL

  /// 用于给 [CachedNetworkImage] 加载 WebDAV 资源的认证请求头。
  final Map<String, String> imageHeaders;

  /// 当前发布进度 0.0 ~ 1.0；没有发布任务时为 0
  final double uploadProgress;

  /// 发布状态描述，如 "正在上传第 2/5 张图片..."
  final String? uploadStatusText;

  /// 排序模式
  final FeedSortMode sortMode;

  /// 日期筛选范围
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;

  const FeedState({
    this.status = FeedStatus.initial,
    this.posts = const [],
    this.filteredPosts = const [],
    this.columnCount = 2,
    this.searchKeyword,
    this.selectedTag,
    this.errorMessage,
    this.mediaBaseUrl,
    this.imageHeaders = const {},
    this.uploadProgress = 0,
    this.uploadStatusText,
    this.sortMode = FeedSortMode.newest,
    this.filterStartDate,
    this.filterEndDate,
  });

  FeedState copyWith({
    FeedStatus? status,
    List<Post>? posts,
    List<Post>? filteredPosts,
    int? columnCount,
    String? searchKeyword,
    String? selectedTag,
    String? errorMessage,
    String? mediaBaseUrl,
    Map<String, String>? imageHeaders,
    double? uploadProgress,
    String? uploadStatusText,
    FeedSortMode? sortMode,
    DateTime? filterStartDate,
    DateTime? filterEndDate,
    bool clearDateFilter = false,
  }) {
    return FeedState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      filteredPosts: filteredPosts ?? this.filteredPosts,
      columnCount: columnCount ?? this.columnCount,
      searchKeyword: searchKeyword ?? this.searchKeyword,
      selectedTag: selectedTag ?? this.selectedTag,
      errorMessage: errorMessage,
      mediaBaseUrl: mediaBaseUrl ?? this.mediaBaseUrl,
      imageHeaders: imageHeaders ?? this.imageHeaders,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      uploadStatusText: uploadStatusText ?? this.uploadStatusText,
      sortMode: sortMode ?? this.sortMode,
      filterStartDate:
          clearDateFilter ? null : (filterStartDate ?? this.filterStartDate),
      filterEndDate:
          clearDateFilter ? null : (filterEndDate ?? this.filterEndDate),
    );
  }

  @override
  List<Object?> get props => [
        status,
        posts,
        filteredPosts,
        columnCount,
        searchKeyword,
        selectedTag,
        errorMessage,
        mediaBaseUrl,
        imageHeaders,
        uploadProgress,
        uploadStatusText,
        sortMode,
        filterStartDate,
        filterEndDate,
      ];
}

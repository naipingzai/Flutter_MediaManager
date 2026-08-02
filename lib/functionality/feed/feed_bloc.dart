import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../models/post.dart';
import '../../services/webdav_service.dart';
import '../../services/log_service.dart';
import '../../utils/error_helper.dart';

part 'feed_event.dart';
part 'feed_state.dart';

final _logger = Logger();
const _uuid = Uuid();

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  WebDavService? _webDavService;
  LogService? _logService;
  JournalData? _journalData;
  Function()? onAuthError;

  FeedBloc() : super(const FeedState()) {
    on<FeedLoadEvent>(_onLoad);
    on<FeedCreatePostEvent>(_onCreatePost);
    on<FeedEditPostEvent>(_onEditPost);
    on<FeedDeletePostEvent>(_onDeletePost);
    on<FeedSearchEvent>(_onSearch);
    on<FeedFilterByTagEvent>(_onFilterByTag);
    on<FeedClearFilterEvent>(_onClearFilter);
    on<FeedColumnChangedEvent>(_onColumnChanged);
    on<FeedSortChangedEvent>(_onSortChanged);
    on<FeedDateFilterEvent>(_onDateFilter);
  }

  void setWebDavService(WebDavService service) {
    _webDavService = service;
  }

  void setLogService(LogService? log) {
    _logService = log;
  }

  void setOnAuthError(Function() callback) {
    onAuthError = callback;
  }

  Future<void> _onLoad(FeedLoadEvent event, Emitter<FeedState> emit) async {
    if (_webDavService == null) {
      emit(state.copyWith(
          status: FeedStatus.error, errorMessage: '未连接到 WebDAV 服务器'));
      return;
    }
    emit(state.copyWith(status: FeedStatus.loading));
    try {
      _journalData = await _webDavService!.loadJournalData();
      final sorted = _applySort(_journalData!.posts, state.sortMode);
      final filtered = _applyAllFilters(
          sorted, state.searchKeyword, state.selectedTag,
          startDate: state.filterStartDate, endDate: state.filterEndDate);
      emit(state.copyWith(
        status: FeedStatus.loaded,
        posts: sorted,
        filteredPosts: filtered,
        mediaBaseUrl: _webDavService!.config.mediaUrl,
        imageHeaders: _webDavService!.imageHeaders,
        encryptionEnabled: _webDavService!.encryption.isEncryptionEnabled,
      ));
    } catch (e) {
      _logService?.error('加载帖子失败', detail: e.toString(), source: 'Feed');
      _logger.e('加载帖子失败: $e');
      if (ErrorHelper.isAuthError(e)) {
        onAuthError?.call();
        emit(state.copyWith(
          status: FeedStatus.error,
          errorMessage: ErrorHelper.friendly(e, prefix: '会话已过期，'),
        ));
      } else {
        emit(state.copyWith(
          status: FeedStatus.error,
          errorMessage: ErrorHelper.friendly(e, prefix: '加载失败：'),
        ));
      }
    }
  }

  Future<void> _onCreatePost(
      FeedCreatePostEvent event, Emitter<FeedState> emit) async {
    if (_webDavService == null) {
      _logService?.warn('创建帖子失败：未连接WebDAV', source: 'Feed');
      return;
    }
    _logService?.info('开始创建帖子',
        detail: '内容长度=${event.content.length}', source: 'Feed');
    try {
      final now = DateTime.now();
      final mediaFiles = <String>[];
      final totalFiles = event.localMediaPaths.length +
          (event.videoPath != null ? 1 : 0) +
          (event.audioPath != null ? 1 : 0);
      var uploadedFiles = 0;

      emit(state.copyWith(
        status: FeedStatus.publishing,
        uploadProgress: 0,
        uploadStatusText: totalFiles > 0 ? '准备上传...' : '保存中...',
      ));

      // 上传图片
      for (var i = 0; i < event.localMediaPaths.length; i++) {
        final localPath = event.localMediaPaths[i];
        final remoteFileName = _webDavService!.generateMediaFileName(localPath);
        final remoteUrl = _webDavService!.getMediaUrl(remoteFileName);
        emit(state.copyWith(
          uploadStatusText:
              '正在上传第 ${i + 1}/${event.localMediaPaths.length} 张图片...',
          uploadProgress:
              (uploadedFiles + 0.5) / (totalFiles > 0 ? totalFiles + 1 : 1),
        ));
        await _webDavService!.uploadFile(localPath, remoteUrl);
        mediaFiles.add(remoteFileName);
        uploadedFiles++;
        emit(state.copyWith(
          uploadProgress: uploadedFiles / (totalFiles > 0 ? totalFiles + 1 : 1),
        ));
      }

      // 上传视频
      String? videoFile;
      String? videoThumbnail;
      if (event.videoPath != null) {
        final videoFileName = _webDavService!
            .generateMediaFileName(event.videoPath!, isVideo: true);
        final remoteUrl = _webDavService!.getMediaUrl(videoFileName);
        emit(state.copyWith(
          uploadStatusText: '正在上传视频...',
          uploadProgress:
              (uploadedFiles + 0.5) / (totalFiles > 0 ? totalFiles + 1 : 1),
        ));
        await _webDavService!.uploadFileWithProgress(
          event.videoPath!,
          remoteUrl,
          onProgress: (progress, speed) {
            emit(state.copyWith(
              uploadStatusText: '正在上传视频 \$speed',
              uploadProgress:
                  (uploadedFiles + progress) / (totalFiles > 0 ? totalFiles + 1 : 1),
            ));
          },
        );
        videoFile = videoFileName;
        uploadedFiles++;

        // 生成视频封面
        try {
          final thumbPath = await VideoThumbnail.thumbnailFile(
            video: event.videoPath!,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 480,
            quality: 75,
          );
          if (thumbPath != null) {
            final thumbFileName = videoFileName.replaceAll(
                RegExp(r'\.[^.]+$'), '.thumb.jpg');
            final thumbRemoteUrl = _webDavService!.getMediaUrl(thumbFileName);
            await _webDavService!.uploadFile(thumbPath, thumbRemoteUrl);
            videoThumbnail = thumbFileName;
          }
        } catch (e) {
          _logService?.warn('视频封面生成失败', detail: e.toString(), source: 'Feed');
        }
      }

      // 上传音频
      // ignore: unused_local_variable
      String? audioFile;
      if (event.audioPath != null) {
        final audioFileName = _webDavService!
            .generateMediaFileName(event.audioPath!, isVideo: true);
        final remoteUrl = _webDavService!.getMediaUrl(audioFileName);
        emit(state.copyWith(
          uploadStatusText: '正在上传音频...',
          uploadProgress:
              (uploadedFiles + 0.5) / (totalFiles > 0 ? totalFiles + 1 : 1),
        ));
        await _webDavService!.uploadFile(event.audioPath!, remoteUrl);
        audioFile = audioFileName;
        uploadedFiles++;
      }

      emit(state.copyWith(
        uploadStatusText: '正在保存动态...',
        uploadProgress: totalFiles > 0 ? totalFiles / (totalFiles + 1) : 0.5,
      ));

      final post = Post(
        id: _uuid.v4(),
        content: event.content,
        mediaFiles: mediaFiles,
        videoFile: videoFile,
        videoThumbnail: videoThumbnail,
        tags: event.tags,
        createdAt: now,
        updatedAt: now,
      );

      final updatedPosts = <Post>[post, ...(_journalData?.posts ?? [])];
      _journalData = JournalData(
        version: 1,
        lastModified: now.toUtc(),
        posts: updatedPosts,
      );

      await _webDavService!.saveJournalData(_journalData!);
      _logService?.success('帖子创建成功', detail: 'id=${post.id}', source: 'Feed');

      final sorted = _applySort(updatedPosts, state.sortMode);
      emit(state.copyWith(
        status: FeedStatus.loaded,
        posts: sorted,
        filteredPosts: _applyAllFilters(
            sorted, state.searchKeyword, state.selectedTag,
            startDate: state.filterStartDate, endDate: state.filterEndDate),
        mediaBaseUrl: _webDavService!.config.mediaUrl,
        imageHeaders: _webDavService!.imageHeaders,
        encryptionEnabled: _webDavService!.encryption.isEncryptionEnabled,
        uploadProgress: 1.0,
        uploadStatusText: '发布完成',
      ));
    } catch (e) {
      _logService?.error('创建帖子失败', detail: e.toString(), source: 'Feed');
      emit(state.copyWith(
        status: FeedStatus.error,
        errorMessage: '发布失败: $e',
        uploadProgress: 0,
        uploadStatusText: null,
      ));
    }
  }

  Future<void> _onEditPost(
      FeedEditPostEvent event, Emitter<FeedState> emit) async {
    if (_webDavService == null || _journalData == null) {
      _logService?.warn('编辑帖子失败：未连接WebDAV', source: 'Feed');
      return;
    }
    _logService?.info('开始编辑帖子',
        detail: 'postId=${event.postId}', source: 'Feed');
    try {
      emit(state.copyWith(status: FeedStatus.editing, uploadProgress: 0));

      // 找到原帖子
      final originalPost =
          _journalData!.posts.firstWhere((p) => p.id == event.postId);

      // 删除被移除的媒体文件
      for (final fileName in event.removedMediaFiles) {
        final url = _webDavService!.getMediaUrl(fileName);
        try {
          await _webDavService!.deleteFile(url);
        } catch (e) {
          _logService?.warn('删除旧媒体文件失败: $fileName',
              detail: e.toString(), source: 'Feed');
        }
      }

      // 保留的媒体文件
      final keepMediaFiles = originalPost.mediaFiles
          .where((f) => !event.removedMediaFiles.contains(f))
          .toList();

      // 上传新增的图片
      final newMediaFiles = <String>[];
      final totalNew = event.newLocalMediaPaths.length +
          (event.newVideoPath != null ? 1 : 0) +
          (event.newAudioPath != null ? 1 : 0);
      var uploaded = 0;

      for (var i = 0; i < event.newLocalMediaPaths.length; i++) {
        final localPath = event.newLocalMediaPaths[i];
        final remoteFileName = _webDavService!.generateMediaFileName(localPath);
        final remoteUrl = _webDavService!.getMediaUrl(remoteFileName);
        emit(state.copyWith(
          uploadStatusText:
              '上传图片 ${i + 1}/${event.newLocalMediaPaths.length}...',
          uploadProgress: totalNew > 0 ? uploaded / totalNew : 0,
        ));
        await _webDavService!.uploadFile(localPath, remoteUrl);
        newMediaFiles.add(remoteFileName);
        uploaded++;
      }

      // 上传新视频（替换旧视频）
      String? videoFile = originalPost.videoFile;
      if (event.newVideoPath != null) {
        if (videoFile != null) {
          try {
            await _webDavService!
                .deleteFile(_webDavService!.getMediaUrl(videoFile));
          } catch (_) {}
        }
        final fileName = _webDavService!
            .generateMediaFileName(event.newVideoPath!, isVideo: true);
        final remoteUrl = _webDavService!.getMediaUrl(fileName);
        await _webDavService!.uploadFile(event.newVideoPath!, remoteUrl);
        videoFile = fileName;
        uploaded++;
      }

      emit(state.copyWith(
        uploadStatusText: '保存中...',
        uploadProgress: 0.9,
      ));

      final updatedPost = Post(
        id: originalPost.id,
        content: event.content,
        mediaFiles: [...keepMediaFiles, ...newMediaFiles],
        videoFile: videoFile,
        tags: event.tags,
        createdAt: originalPost.createdAt,
        updatedAt: DateTime.now(),
      );

      final updatedPosts = _journalData!.posts
          .map((p) => p.id == event.postId ? updatedPost : p)
          .toList();

      _journalData = JournalData(
        version: 1,
        lastModified: DateTime.now().toUtc(),
        posts: updatedPosts,
      );

      await _webDavService!.saveJournalData(_journalData!);
      _logService?.success('帖子编辑成功',
          detail: 'postId=${event.postId}', source: 'Feed');

      final sorted = _applySort(updatedPosts, state.sortMode);
      emit(state.copyWith(
        status: FeedStatus.loaded,
        posts: sorted,
        filteredPosts: _applyAllFilters(
            sorted, state.searchKeyword, state.selectedTag,
            startDate: state.filterStartDate, endDate: state.filterEndDate),
        mediaBaseUrl: _webDavService!.config.mediaUrl,
        imageHeaders: _webDavService!.imageHeaders,
        encryptionEnabled: _webDavService!.encryption.isEncryptionEnabled,
        uploadProgress: 1.0,
        uploadStatusText: '编辑完成',
      ));
    } catch (e) {
      _logService?.error('编辑帖子失败', detail: e.toString(), source: 'Feed');
      emit(state.copyWith(
        status: FeedStatus.error,
        errorMessage: '编辑失败: $e',
        uploadProgress: 0,
        uploadStatusText: null,
      ));
    }
  }

  Future<void> _onDeletePost(
      FeedDeletePostEvent event, Emitter<FeedState> emit) async {
    if (_webDavService == null || _journalData == null) {
      _logService?.warn('删除帖子失败：未连接WebDAV', source: 'Feed');
      return;
    }
    _logService?.info('开始删除帖子',
        detail: 'postId=${event.postId}', source: 'Feed');
    try {
      emit(state.copyWith(status: FeedStatus.syncing));

      final post = _journalData!.posts.firstWhere((p) => p.id == event.postId);

      // 删除关联的媒体文件
      for (final fileName in post.mediaFiles) {
        final url = _webDavService!.getMediaUrl(fileName);
        await _webDavService!.deleteFile(url);
      }
      if (post.videoFile != null) {
        final url = _webDavService!.getMediaUrl(post.videoFile!);
        await _webDavService!.deleteFile(url);
      }

      final updatedPosts =
          _journalData!.posts.where((p) => p.id != event.postId).toList();
      _journalData = JournalData(
        version: 1,
        lastModified: DateTime.now().toUtc(),
        posts: updatedPosts,
      );

      await _webDavService!.saveJournalData(_journalData!);
      _logService?.success('帖子删除成功',
          detail: 'postId=${event.postId}', source: 'Feed');

      final sorted = _applySort(updatedPosts, state.sortMode);
      emit(state.copyWith(
        status: FeedStatus.loaded,
        posts: sorted,
        filteredPosts: _applyAllFilters(
            sorted, state.searchKeyword, state.selectedTag,
            startDate: state.filterStartDate, endDate: state.filterEndDate),
      ));
    } catch (e) {
      _logService?.error('删除帖子失败', detail: e.toString(), source: 'Feed');
      emit(state.copyWith(status: FeedStatus.error, errorMessage: '删除失败: $e'));
    }
  }

  void _onSearch(FeedSearchEvent event, Emitter<FeedState> emit) {
    _logService?.info('搜索帖子',
        detail: 'keyword=${event.keyword}', source: 'Feed');
    if (event.keyword.isEmpty) {
      emit(state.copyWith(
        filteredPosts: _applyAllFilters(state.posts, null, state.selectedTag,
            startDate: state.filterStartDate, endDate: state.filterEndDate),
        searchKeyword: null,
      ));
      return;
    }
    final results = _applyAllFilters(
        state.posts, event.keyword, state.selectedTag,
        startDate: state.filterStartDate, endDate: state.filterEndDate);
    emit(state.copyWith(
      filteredPosts: results,
      searchKeyword: event.keyword,
    ));
  }

  void _onFilterByTag(FeedFilterByTagEvent event, Emitter<FeedState> emit) {
    _logService?.info('按标签过滤', detail: 'tag=${event.tag}', source: 'Feed');
    final results = _applyAllFilters(
        state.posts, state.searchKeyword, event.tag,
        startDate: state.filterStartDate, endDate: state.filterEndDate);
    emit(state.copyWith(
      filteredPosts: results,
      selectedTag: event.tag,
    ));
  }

  void _onClearFilter(FeedClearFilterEvent event, Emitter<FeedState> emit) {
    _logService?.info('清除过滤条件', source: 'Feed');
    emit(state.copyWith(
      filteredPosts: state.posts,
      searchKeyword: null,
      selectedTag: null,
      clearDateFilter: true,
    ));
  }

  void _onColumnChanged(FeedColumnChangedEvent event, Emitter<FeedState> emit) {
    _logService?.info('切换列数',
        detail: 'columns=${event.columnCount}', source: 'Feed');
    emit(state.copyWith(columnCount: event.columnCount.clamp(1, 4)));
  }

  void _onSortChanged(FeedSortChangedEvent event, Emitter<FeedState> emit) {
    _logService?.info('切换排序', detail: 'sort=${event.sortMode}', source: 'Feed');
    final sorted = _applySort(state.posts, event.sortMode);
    final filtered = _applyAllFilters(
        sorted, state.searchKeyword, state.selectedTag,
        startDate: state.filterStartDate, endDate: state.filterEndDate);
    emit(state.copyWith(
      posts: sorted,
      filteredPosts: filtered,
      sortMode: event.sortMode,
    ));
  }

  void _onDateFilter(FeedDateFilterEvent event, Emitter<FeedState> emit) {
    _logService?.info('日期筛选',
        detail: '${event.startDate} ~ ${event.endDate}', source: 'Feed');
    final filtered = _applyAllFilters(
        state.posts, state.searchKeyword, state.selectedTag,
        startDate: event.startDate, endDate: event.endDate);
    emit(state.copyWith(
      filteredPosts: filtered,
      filterStartDate: event.startDate,
      filterEndDate: event.endDate,
      clearDateFilter: event.startDate == null && event.endDate == null,
    ));
  }

  /// 排序帖子列表
  List<Post> _applySort(List<Post> posts, FeedSortMode sortMode) {
    final sorted = List<Post>.from(posts);
    switch (sortMode) {
      case FeedSortMode.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case FeedSortMode.oldest:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case FeedSortMode.contentAsc:
        sorted.sort((a, b) =>
            a.content.toLowerCase().compareTo(b.content.toLowerCase()));
      case FeedSortMode.contentDesc:
        sorted.sort((a, b) =>
            b.content.toLowerCase().compareTo(a.content.toLowerCase()));
      case FeedSortMode.mediaCountDesc:
        sorted
            .sort((a, b) => b.mediaFiles.length.compareTo(a.mediaFiles.length));
    }
    return sorted;
  }

  /// 综合过滤（关键词 + 标签 + 日期范围）
  List<Post> _applyAllFilters(
    List<Post> posts,
    String? keyword,
    String? tag, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    var result = posts;

    // 关键词过滤
    if (keyword != null && keyword.isNotEmpty) {
      final lowerKeyword = keyword.toLowerCase();
      result = result.where((p) {
        return p.content.toLowerCase().contains(lowerKeyword) ||
            p.tags.any((t) => t.toLowerCase().contains(lowerKeyword));
      }).toList();
    }

    // 标签过滤
    if (tag != null && tag.isNotEmpty) {
      result = result.where((p) => p.tags.contains(tag)).toList();
    }

    // 日期范围过滤
    if (startDate != null) {
      result = result
          .where((p) =>
              p.createdAt.isAfter(startDate.subtract(const Duration(days: 1))))
          .toList();
    }
    if (endDate != null) {
      result = result
          .where(
              (p) => p.createdAt.isBefore(endDate.add(const Duration(days: 1))))
          .toList();
    }

    return result;
  }
}

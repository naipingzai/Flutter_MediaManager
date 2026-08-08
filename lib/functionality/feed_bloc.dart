import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/post.dart';
import '../services/sync_service.dart';
import '../services/log_service.dart';
import '../ui/error_helper.dart';

part 'feed_event.dart';
part 'feed_state.dart';

const _uuid = Uuid();

/// 后台 isolate 复制文件（compute 的顶层函数）
Future<void> _copyFileInIsolate((String, String) args) async {
  await File(args.$1).copy(args.$2);
}

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  /// ★ 重构：只依赖 SyncService，不直接依赖 WebDavService
  /// SyncService 是本地与云端的唯一桥梁
  SyncService? _syncService;
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
    on<FeedRefreshEvent>(_onRefresh);
  }

  void setSyncService(SyncService service) {
    _syncService = service;
  }

  void setLogService(LogService? log) {
    _logService = log;
  }

  void setOnAuthError(Function() callback) {
    onAuthError = callback;
  }

  /// 手动触发一次同步推送（通过 SyncService 代理，不再直接依赖 WebDAV）
  Future<bool> performManualSync({String? nickname, String? avatarPath}) async {
    if (_syncService == null || !_syncService!.hasCloudConnection) return false;
    if (_journalData == null) return false;
    return await _syncService!.performFullSync(
      nickname: nickname,
      avatarPath: avatarPath,
    );
  }

  Future<void> _onLoad(FeedLoadEvent event, Emitter<FeedState> emit) async {
    final hasSync = _syncService != null;

    // 1. 加载本地数据（始终执行）
    if (hasSync) {
      final localData = await _syncService!.loadLocalData();
      if (localData != null) {
        _journalData = localData;
        _emitLoaded(emit, localData);
        _logService?.info('本地数据已加载',
            detail: '${localData.posts.length} 条', source: 'Feed');
      }
    }

    // 2. 没有云端连接 → 只用本地数据
    if (hasSync && !_syncService!.hasCloudConnection) {
      if (_journalData == null) {
        _journalData = JournalData.empty();
        _emitLoaded(emit, _journalData!);
      }
      return;
    }

    // 3. 有待同步数据 → 后台推送
    if (hasSync && _syncService!.pendingSync && _journalData != null) {
      _logService?.info('后台推送待同步数据...', source: 'Feed');
      _syncService!.pushPendingData().then((_) {
        if (!isClosed) add(const FeedRefreshEvent());
      });
    }

    // 4. 从云端拉取数据并合并
    if (hasSync) {
      _syncService!.pullAndMerge(localData: _journalData).then((merged) {
        if (merged != null) {
          _journalData = merged;
          _syncService!.createSnapshot(merged);
        }
        if (!isClosed) add(const FeedRefreshEvent());
      }).catchError((e) {
        _logService?.warn('后台拉取云端数据失败', detail: e.toString(), source: 'Feed');
        if (_journalData == null || _journalData!.posts.isEmpty) {
          if (!isClosed && ErrorHelper.isAuthError(e)) {
            onAuthError?.call();
          }
        }
      });
    }

    if (_journalData == null) {
      emit(state.copyWith(status: FeedStatus.loading));
    }
  }

  void _emitLoaded(Emitter<FeedState> emit, JournalData data) {
    final sorted = _applySort(data.posts, state.sortMode);
    final filtered = _applyAllFilters(
        sorted, state.searchKeyword, state.selectedTag,
        startDate: state.filterStartDate, endDate: state.filterEndDate);
    emit(state.copyWith(
      status: FeedStatus.loaded,
      posts: sorted,
      filteredPosts: filtered,
      // 通过 SyncService 获取云端信息（UI 层不再直接依赖 WebDavService）
      mediaBaseUrl: _syncService?.mediaBaseUrl,
      imageHeaders: _syncService?.imageHeaders ?? {},
    ));
  }

  void _onRefresh(FeedRefreshEvent event, Emitter<FeedState> emit) {
    if (_journalData == null) return;
    _emitLoaded(emit, _journalData!);
  }

  Future<void> _onCreatePost(
      FeedCreatePostEvent event, Emitter<FeedState> emit) async {
    _logService?.info('开始创建帖子（本地保存）',
        detail: '内容长度=${event.content.length}', source: 'Feed');
    try {
      final now = DateTime.now();
      final mediaFiles = <String>[];
      final totalFiles = event.localMediaPaths.length +
          (event.videoPath != null ? 1 : 0) +
          (event.audioPath != null ? 1 : 0);
      var processedFiles = 0;

      emit(state.copyWith(
        status: FeedStatus.publishing,
        uploadProgress: 0,
        uploadStatusText: totalFiles > 0 ? '正在保存媒体...' : '保存中...',
      ));

      for (var i = 0; i < event.localMediaPaths.length; i++) {
        final localPath = event.localMediaPaths[i];
        final fileName = _generateLocalFileName(localPath);
        emit(state.copyWith(
          uploadStatusText:
              '正在保存第 ${i + 1}/${event.localMediaPaths.length} 张图片...',
          uploadProgress:
              (processedFiles + 0.5) / (totalFiles > 0 ? totalFiles + 1 : 1),
        ));
        await _saveMediaFileLocally(localPath, fileName);
        mediaFiles.add(fileName);
        processedFiles++;
        emit(state.copyWith(
          uploadProgress:
              processedFiles / (totalFiles > 0 ? totalFiles + 1 : 1),
        ));
      }

      String? videoFile;
      String? videoThumbnail;
      if (event.videoPath != null) {
        final videoFileName =
            _generateLocalFileName(event.videoPath!, isVideo: true);
        emit(state.copyWith(
          uploadStatusText: '正在保存视频...',
          uploadProgress:
              (processedFiles + 0.5) / (totalFiles > 0 ? totalFiles + 1 : 1),
        ));
        await _saveMediaFileLocally(event.videoPath!, videoFileName);
        videoFile = videoFileName;
        processedFiles++;

        if (!kIsWeb && !Platform.isLinux && !Platform.isWindows) {
          try {
            final thumbPath =
                await _generateVideoThumbnail(event.videoPath!, videoFileName);
            if (thumbPath != null) videoThumbnail = thumbPath;
          } catch (e) {
            _logService?.warn('视频封面生成跳过', detail: e.toString(), source: 'Feed');
          }
        }
      }

      String? audioFile;
      if (event.audioPath != null) {
        final audioFileName =
            _generateLocalFileName(event.audioPath!, isVideo: true);
        emit(state.copyWith(
          uploadStatusText: '正在保存音频...',
          uploadProgress:
              (processedFiles + 0.5) / (totalFiles > 0 ? totalFiles + 1 : 1),
        ));
        await _saveMediaFileLocally(event.audioPath!, audioFileName);
        audioFile = audioFileName;
        processedFiles++;
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

      if (_syncService != null) {
        await _syncService!.saveLocalData(_journalData!);
        await _syncService!.markPendingSync(true);
      }
      _logService?.success('帖子创建成功（本地）',
          detail: 'id=${post.id}', source: 'Feed');

      final sorted = _applySort(updatedPosts, state.sortMode);
      emit(state.copyWith(
        status: FeedStatus.loaded,
        posts: sorted,
        filteredPosts: _applyAllFilters(
            sorted, state.searchKeyword, state.selectedTag,
            startDate: state.filterStartDate, endDate: state.filterEndDate),
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

  Future<String?> _generateVideoThumbnail(
      String videoPath, String videoFileName) async {
    String? outPath;
    try {
      outPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 75,
        timeMs: 1000,
      ).timeout(const Duration(seconds: 10), onTimeout: () => null);
    } catch (_) {}
    if (outPath == null) {
      try {
        outPath = await VideoThumbnail.thumbnailFile(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 480,
          quality: 75,
          timeMs: 0,
        ).timeout(const Duration(seconds: 10), onTimeout: () => null);
      } catch (_) {}
    }
    if (outPath == null) return null;
    final thumbFileName =
        videoFileName.replaceAll(RegExp(r'\.[^.]+$'), '.thumb.jpg');
    await _saveMediaFileLocally(outPath, thumbFileName);
    _logService?.info('视频封面已生成', detail: thumbFileName, source: 'Feed');
    return thumbFileName;
  }

  String _generateLocalFileName(String path, {bool isVideo = false}) {
    final ext = path.split('.').last;
    final now = DateTime.now();
    final ts =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    final type = isVideo ? 'VID' : 'IMG';
    return '${type}_${_uuid.v4().substring(0, 8)}_$ts.$ext';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<void> _saveMediaFileLocally(String sourcePath, String fileName) async {
    if (_syncService != null) {
      final localPath = await _syncService!.getLocalMediaPath(fileName);
      // 使用后台 isolate 复制文件，避免大文件阻塞 UI
      await compute(_copyFileInIsolate, (sourcePath, localPath));
      _syncService!.localMediaFiles.add(fileName);
      _logService?.info('本地保存媒体: $fileName', source: 'Feed');
    }
  }

  Future<void> _onEditPost(
      FeedEditPostEvent event, Emitter<FeedState> emit) async {
    if (_journalData == null) {
      _logService?.warn('编辑帖子失败：无数据', source: 'Feed');
      return;
    }
    _logService?.info('开始编辑帖子（本地操作）',
        detail: 'postId=${event.postId}', source: 'Feed');
    try {
      emit(state.copyWith(status: FeedStatus.editing, uploadProgress: 0));

      final originalPost =
          _journalData!.posts.firstWhere((p) => p.id == event.postId);

      for (final fileName in event.removedMediaFiles) {
        if (_syncService != null) {
          await _syncService!.deleteMedia(fileName);
        }
      }

      final keepMediaFiles = originalPost.mediaFiles
          .where((f) => !event.removedMediaFiles.contains(f))
          .toList();

      final newMediaFiles = <String>[];
      final totalNew = event.newLocalMediaPaths.length +
          (event.newVideoPath != null ? 1 : 0) +
          (event.newAudioPath != null ? 1 : 0);
      var processed = 0;

      for (var i = 0; i < event.newLocalMediaPaths.length; i++) {
        final localPath = event.newLocalMediaPaths[i];
        final fileName = _generateLocalFileName(localPath);
        emit(state.copyWith(
          uploadStatusText:
              '保存图片 ${i + 1}/${event.newLocalMediaPaths.length}...',
          uploadProgress: totalNew > 0 ? processed / totalNew : 0,
        ));
        await _saveMediaFileLocally(localPath, fileName);
        newMediaFiles.add(fileName);
        processed++;
      }

      String? videoFile = originalPost.videoFile;
      if (event.newVideoPath != null) {
        if (videoFile != null && _syncService != null) {
          await _syncService!.deleteMedia(videoFile);
        }
        final fileName =
            _generateLocalFileName(event.newVideoPath!, isVideo: true);
        await _saveMediaFileLocally(event.newVideoPath!, fileName);
        videoFile = fileName;
        processed++;
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

      if (_syncService != null) {
        await _syncService!.saveLocalData(_journalData!);
        await _syncService!.markPendingSync(true);
      }
      _logService?.success('帖子编辑成功（本地）',
          detail: 'postId=${event.postId}', source: 'Feed');

      final sorted = _applySort(updatedPosts, state.sortMode);
      emit(state.copyWith(
        status: FeedStatus.loaded,
        posts: sorted,
        filteredPosts: _applyAllFilters(
            sorted, state.searchKeyword, state.selectedTag,
            startDate: state.filterStartDate, endDate: state.filterEndDate),
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
    if (_journalData == null) {
      _logService?.warn('删除帖子失败：无数据', source: 'Feed');
      return;
    }
    _logService?.info('开始删除帖子（本地操作）',
        detail: 'postId=${event.postId}', source: 'Feed');
    try {
      emit(state.copyWith(status: FeedStatus.syncing));
      final post =
          _journalData!.posts.where((p) => p.id == event.postId).firstOrNull;

      if (post == null) {
        _logService?.warn('删除帖子失败：未找到帖子',
            detail: 'postId=${event.postId}', source: 'Feed');
        final sorted = _applySort(_journalData!.posts, state.sortMode);
        emit(state.copyWith(
          status: FeedStatus.loaded,
          posts: sorted,
          filteredPosts: _applyAllFilters(
              sorted, state.searchKeyword, state.selectedTag,
              startDate: state.filterStartDate, endDate: state.filterEndDate),
        ));
        return;
      }

      if (_syncService != null) {
        for (final fileName in post.mediaFiles) {
          await _syncService!.deleteMedia(fileName);
        }
        if (post.videoFile != null) {
          await _syncService!.deleteMedia(post.videoFile!);
        }
        if (post.videoThumbnail != null) {
          await _syncService!.deleteMedia(post.videoThumbnail!);
        }
      }

      final updatedPosts =
          _journalData!.posts.where((p) => p.id != event.postId).toList();
      _journalData = JournalData(
        version: 1,
        lastModified: DateTime.now().toUtc(),
        posts: updatedPosts,
      );

      if (_syncService != null) {
        await _syncService!.saveLocalData(_journalData!);
        await _syncService!.markPendingSync(true);
      }
      _logService?.success('帖子删除成功（本地）',
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

  List<Post> _applyAllFilters(
    List<Post> posts,
    String? keyword,
    String? tag, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    var result = posts;
    if (keyword != null && keyword.isNotEmpty) {
      final lowerKeyword = keyword.toLowerCase();
      result = result.where((p) {
        return p.content.toLowerCase().contains(lowerKeyword) ||
            p.tags.any((t) => t.toLowerCase().contains(lowerKeyword));
      }).toList();
    }
    if (tag != null && tag.isNotEmpty) {
      result = result.where((p) => p.tags.contains(tag)).toList();
    }
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

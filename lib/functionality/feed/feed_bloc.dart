import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../models/post.dart';
import '../../services/webdav_service.dart';
import '../../services/cache_service.dart';
import '../../services/log_service.dart';
import '../../utils/error_helper.dart';

part 'feed_event.dart';
part 'feed_state.dart';

const _uuid = Uuid();

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  WebDavService? _webDavService;
  CacheService? _cacheService;
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

  void setWebDavService(WebDavService service) {
    _webDavService = service;
  }

  void setCacheService(CacheService service) {
    _cacheService = service;
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

    final hasLocalSync = _cacheService != null && _cacheService!.enabled;
    final hasPendingSync = hasLocalSync && _cacheService!.pendingSync;

    // Step 1: 立即加载本地数据（不阻塞）
    if (hasLocalSync) {
      final localData = await _cacheService!.loadLocalData();
      if (localData != null) {
        _journalData = localData;
        _emitLoaded(emit, localData);
        _logService?.info('本地数据已加载', detail: '${localData.posts.length} 条', source: 'Feed');
      }
    }

    // Step 2: 如果有待同步数据，后台推送（不阻塞，fire-and-forget）
    if (hasPendingSync) {
      _logService?.info('后台推送待同步数据...', source: 'Feed');
      _cacheService!.pushToWebDav(
        uploadFn: (localPath, remoteUrl) => _webDavService!.uploadFile(localPath, remoteUrl),
        saveDataFn: (data) => _webDavService!.saveJournalData(data),
        mediaBaseUrl: _webDavService!.config.mediaUrl,
      ).then((ok) {
        if (ok) _logService?.success('后台推送完成', source: 'Feed');
      });
    }

    // Step 3: 后台拉取 WebDAV 最新数据（不阻塞，完成后合并）
    _webDavService!.loadJournalData().then((remoteData) async {
      if (hasLocalSync && _journalData != null) {
        // 合并：以 WebDAV 为基准，加上本地独有的帖子
        final merged = _mergePosts(_journalData!, remoteData);
        _journalData = merged;
        await _cacheService!.createSnapshot(merged);
        await _cacheService!.saveLocalData(merged);
      } else {
        _journalData = remoteData;
        if (hasLocalSync) {
          await _cacheService!.saveLocalData(remoteData);
        }
      }
      // 通知 UI 刷新（通过 add event 而非 emit，因为是异步回调）
      if (!isClosed) {
        add(const FeedRefreshEvent());
      }
    }).catchError((e) {
      _logService?.warn('后台拉取 WebDAV 失败', detail: e.toString(), source: 'Feed');
      // WebDAV 失败时，如果本地也没数据，显示错误
      if (_journalData == null || (_journalData!.posts.isEmpty)) {
        if (!isClosed) {
          if (ErrorHelper.isAuthError(e)) {
            onAuthError?.call();
          }
        }
      }
    });

    // 如果本地没数据，先显示 loading 等后台完成
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
      mediaBaseUrl: _webDavService!.config.mediaUrl,
      imageHeaders: _webDavService!.imageHeaders,
      encryptionEnabled: _webDavService!.encryption.isEncryptionEnabled,
    ));
  }

  /// 合并本地和远程数据：以远程为基准，加上本地独有的帖子
  JournalData _mergePosts(JournalData local, JournalData remote) {
    final remoteIds = remote.posts.map((p) => p.id).toSet();
    final localOnly = local.posts.where((p) => !remoteIds.contains(p.id)).toList();
    final merged = <Post>[...remote.posts, ...localOnly];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return JournalData(
      version: 1,
      lastModified: DateTime.now().toUtc(),
      posts: merged,
    );
  }

  /// 后台同步完成后刷新 UI
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

      // 保存图片到本地
      for (var i = 0; i < event.localMediaPaths.length; i++) {
        final localPath = event.localMediaPaths[i];
        final fileName = _generateLocalFileName(localPath);
        emit(state.copyWith(
          uploadStatusText:
              '正在保存第 ${i + 1}/${event.localMediaPaths.length} 张图片...',
          uploadProgress:
              (processedFiles + 0.5) / (totalFiles > 0 ? totalFiles + 1 : 1),
        ));
        // 复制文件到本地媒体目录
        await _saveMediaFileLocally(localPath, fileName);
        mediaFiles.add(fileName);
        processedFiles++;
        emit(state.copyWith(
          uploadProgress: processedFiles / (totalFiles > 0 ? totalFiles + 1 : 1),
        ));
      }

      // 保存视频到本地
      String? videoFile;
      String? videoThumbnail;
      if (event.videoPath != null) {
        final videoFileName = _generateLocalFileName(event.videoPath!, isVideo: true);
        emit(state.copyWith(
          uploadStatusText: '正在保存视频...',
          uploadProgress:
              (processedFiles + 0.5) / (totalFiles > 0 ? totalFiles + 1 : 1),
        ));
        await _saveMediaFileLocally(event.videoPath!, videoFileName);
        videoFile = videoFileName;
        processedFiles++;

        // 生成视频封面（仅 Android/iOS，Linux/Windows 不支持）
        if (!kIsWeb && !Platform.isLinux && !Platform.isWindows) {
          try {
            final thumbPath = await VideoThumbnail.thumbnailFile(
              video: event.videoPath!,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 480,
              quality: 75,
            ).timeout(const Duration(seconds: 15), onTimeout: () => null);
            if (thumbPath != null) {
              final thumbFileName = videoFileName.replaceAll(
                  RegExp(r'\.[^.]+$'), '.thumb.jpg');
              await _saveMediaFileLocally(thumbPath, thumbFileName);
              videoThumbnail = thumbFileName;
            }
          } catch (e) {
            _logService?.warn('视频封面生成跳过', detail: e.toString(), source: 'Feed');
          }
        } else {
          _logService?.info('Linux 平台跳过视频封面生成', source: 'Feed');
        }
      }

      // 保存音频到本地
      // ignore: unused_local_variable
      String? audioFile;
      if (event.audioPath != null) {
        final audioFileName = _generateLocalFileName(event.audioPath!, isVideo: true);
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

      // 保存到本地数据
      if (_cacheService != null) {
        await _cacheService!.saveLocalData(_journalData!);
        // 标记有待同步数据
        await _cacheService!.markPendingSync(true);
      }
      _logService?.success('帖子创建成功（本地）', detail: 'id=${post.id}', source: 'Feed');

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

  /// 生成本地文件名（时间戳格式）
  String _generateLocalFileName(String path, {bool isVideo = false}) {
    final ext = path.split('.').last;
    final now = DateTime.now();
    final ts = '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    final type = isVideo ? 'VID' : 'IMG';
    return '${type}_${_uuid.v4().substring(0, 8)}_$ts.$ext';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  /// 保存媒体文件到本地目录（使用文件复制，避免读入内存）
  Future<void> _saveMediaFileLocally(String sourcePath, String fileName) async {
    if (_cacheService != null) {
      final localPath = await _cacheService!.getLocalMediaPath(fileName);
      await File(sourcePath).copy(localPath);
      _cacheService!.cachedFiles.add(fileName);
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

      // 找到原帖子
      final originalPost =
          _journalData!.posts.firstWhere((p) => p.id == event.postId);

      // 本地删除被移除的媒体文件
      for (final fileName in event.removedMediaFiles) {
        if (_cacheService != null) {
          await _cacheService!.deleteMedia(fileName);
        }
      }

      // 保留的媒体文件
      final keepMediaFiles = originalPost.mediaFiles
          .where((f) => !event.removedMediaFiles.contains(f))
          .toList();

      // 本地保存新增的图片
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

      // 本地保存新视频
      String? videoFile = originalPost.videoFile;
      if (event.newVideoPath != null) {
        if (videoFile != null && _cacheService != null) {
          await _cacheService!.deleteMedia(videoFile);
        }
        final fileName = _generateLocalFileName(event.newVideoPath!, isVideo: true);
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

      // 保存到本地
      if (_cacheService != null) {
        await _cacheService!.saveLocalData(_journalData!);
        await _cacheService!.markPendingSync(true);
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

      final post = _journalData!.posts.firstWhere((p) => p.id == event.postId);

      // 本地删除关联的媒体文件
      if (_cacheService != null) {
        for (final fileName in post.mediaFiles) {
          await _cacheService!.deleteMedia(fileName);
        }
        if (post.videoFile != null) {
          await _cacheService!.deleteMedia(post.videoFile!);
        }
      }

      final updatedPosts =
          _journalData!.posts.where((p) => p.id != event.postId).toList();
      _journalData = JournalData(
        version: 1,
        lastModified: DateTime.now().toUtc(),
        posts: updatedPosts,
      );

      // 保存到本地
      if (_cacheService != null) {
        await _cacheService!.saveLocalData(_journalData!);
        await _cacheService!.markPendingSync(true);
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

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../functionality/auth/auth_bloc.dart';
import '../../functionality/feed/feed_bloc.dart';
import '../../models/post.dart';
import '../../services/sync_service.dart';
import '../../services/encryption_service.dart';
import '../../utils/export_helper.dart';
import '../../utils/media_utils.dart';
import 'create_post_screen.dart';

/// 帖子详情页
class PostDetailScreen extends StatelessWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dt = post.createdAt;
    final timeStr =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final screenWidth = MediaQuery.of(context).size.width;
    final feedState = context.read<FeedBloc>().state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('详情'),
        actions: [
          // ★ 任务2: 保存到系统相册 / 分享到其他 APP
          //  区分系统类型：iOS/Android 保存到相册；其他提示用户。
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 22),
            tooltip: '保存到系统',
            onPressed: () => _showExportSheet(context, post),
          ),
          // 右上角菜单：标签管理
          IconButton(
            icon: const Icon(Icons.label_outline_rounded, size: 22),
            tooltip: '标签',
            onPressed: () => _showTagsDialog(context, post),
          ),
          IconButton(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => CreatePostScreen(editPost: post)),
              );
              if (result == true && context.mounted)
                Navigator.pop(context, true);
            },
            icon: const Icon(Icons.edit_location_alt_outlined, size: 22),
            tooltip: '编辑',
          ),
          IconButton(
            onPressed: () => _confirmDelete(context),
            icon: Icon(Icons.delete_outline_rounded, color: cs.error, size: 22),
            tooltip: '删除',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: _buildRichContent(post.content, textTheme, cs),
              ),
            if (post.mediaFiles.isNotEmpty)
              _MediaCarousel(
                  mediaFiles: post.mediaFiles,
                  feedState: feedState,
                  screenWidth: screenWidth),
            if (post.hasVideo)
              _VideoPlayerCard(
                feedState: feedState,
                post: post,
                screenWidth: screenWidth,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(timeStr,
                            style: textTheme.labelMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (post.tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: post.tags
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(tag,
                                    style: textTheme.bodySmall?.copyWith(
                                        color: cs.onPrimaryContainer,
                                        fontWeight: FontWeight.w500)),
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildRichContent(
      String content, TextTheme textTheme, ColorScheme cs) {
    final regex = RegExp(r'#[^\s#]+');
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in regex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
          text: content.substring(match.start + 1, match.end),
          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)));
      lastEnd = match.end;
    }
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }
    return SelectableText.rich(TextSpan(
        style: textTheme.bodyLarge?.copyWith(height: 1.8, fontSize: 16),
        children: spans));
  }

  /// 标签管理弹窗（统一入口）
  void _showTagsDialog(BuildContext context, Post post) {
    final controller = TextEditingController(text: post.tags.join(' '));
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('标签'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: '使用空格分隔，如：日常 天气',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final newTags = controller.text
                  .split(RegExp(r'\s+'))
                  .where((s) => s.trim().isNotEmpty)
                  .map((s) => s.replaceAll(RegExp(r'^#+'), ''))
                  .toList();
              final updated = post.copyWith(tags: newTags);
              // 这里触发 feed bloc 更新（通过事件简化处理）
              final feedBloc = context.read<FeedBloc>();
              if (feedBloc.state.posts.any((p) => p.id == post.id)) {
                // 直接编辑 data
                final state = feedBloc.state;
                final updatedPosts = state.posts
                    .map((p) => p.id == post.id ? updated : p)
                    .toList();
                // 通过创建相同 id 的 edit 事件实现
                feedBloc.add(FeedEditPostEvent(
                  postId: post.id,
                  content: post.content,
                  tags: newTags,
                ));
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('标签已更新'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: cs.primary,
              ));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 任务2：弹出导出/分享菜单，把帖子中的图片/视频保存到系统相册
  ///
  /// 区分系统类型：
  /// - iOS / Android → 保存到系统相册（SaverGallery）
  /// - Desktop / Web → 提示使用下载目录
  void _showExportSheet(BuildContext context, Post post) {
    final sync = context.read<SyncService>();
    final cs = Theme.of(context).colorScheme;

    // 收集所有需要导出的媒体（图片 + 视频）
    final items = <_ExportItem>[];
    for (final fileName in post.mediaFiles) {
      items.add(_ExportItem(
        fileName: fileName,
        isVideo: false,
        displayName: fileName,
      ));
    }
    if (post.videoFile != null) {
      items.add(_ExportItem(
        fileName: post.videoFile!,
        isVideo: true,
        displayName: post.videoFile!,
      ));
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('该动态没有可导出的图片或视频'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(Icons.ios_share_rounded, color: cs.primary),
                  const SizedBox(width: 12),
                  Text(
                    '保存到系统 (${items.length})',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _platformHint(),
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length + 1,
                itemBuilder: (_, idx) {
                  if (idx == items.length) {
                    return ListTile(
                      leading: const Icon(Icons.select_all_rounded),
                      title: const Text('全部保存'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.showSnackBar(const SnackBar(
                          content: Text('正在保存到系统相册...'),
                          behavior: SnackBarBehavior.floating,
                        ));
                        for (final it in items) {
                          final localPath =
                              await sync.getLocalMediaPath(it.fileName);
                          final file = File(localPath);
                          if (!await file.exists()) continue;
                          final res = await ExportHelper.exportToGallery(
                            filePath: localPath,
                            fileName: it.fileName,
                            isVideo: it.isVideo,
                          );
                          if (!context.mounted) break;
                          ExportHelper.showResult(context, res);
                        }
                      },
                    );
                  }
                  final it = items[idx];
                  return ListTile(
                    leading: Icon(it.isVideo
                        ? Icons.videocam_rounded
                        : Icons.image_rounded),
                    title: Text(
                      it.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(it.isVideo ? '视频' : '图片'),
                    trailing: const Icon(Icons.save_alt_rounded),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final localPath =
                          await sync.getLocalMediaPath(it.fileName);
                      final file = File(localPath);
                      if (!await file.exists()) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('文件不存在，请先同步'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      final res = await ExportHelper.exportToGallery(
                        filePath: localPath,
                        fileName: it.fileName,
                        isVideo: it.isVideo,
                      );
                      if (!context.mounted) return;
                      ExportHelper.showResult(context, res);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 根据平台返回保存提示文案
  String _platformHint() {
    // 此方法仅在 iOS/Android/Desktop/Web 上有意义；
    // Flutter 编译时不会报错，因为 [Platform] 在运行时求值。
    // ignore: avoid_dynamic_calls
    if (Platform.isIOS) return 'iOS 设备：保存到「照片」App';
    if (Platform.isAndroid) return 'Android 设备：保存到「相册」';
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return '桌面端：保存到「下载」目录';
    }
    return '保存到系统相册';
  }

  void _confirmDelete(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.delete_outline_rounded, size: 40, color: cs.error),
        title: const Text('删除动态'),
        content: const Text('确定要删除这条动态吗？删除后无法恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () async {
              // ★ 等待 FeedBloc 处理完成后再 pop
              //  避免竞态：pop 后 state 未更新，feed 页看不到删除
              context.read<FeedBloc>().add(FeedDeletePostEvent(post.id));
              Navigator.pop(ctx);  // 关闭确认对话框
              // 等待 BLoC 真正 emit 新状态
              await Future<void>.delayed(const Duration(milliseconds: 200));
              if (context.mounted) Navigator.pop(context);  // 关闭详情页
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('动态已删除')));
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 视频播放器卡片（封面先行 + 点击进入播放）
// ============================================================
class _VideoPlayerCard extends StatefulWidget {
  final FeedState feedState;
  final Post post;
  final double screenWidth;
  const _VideoPlayerCard(
      {required this.feedState, required this.post, required this.screenWidth});

  @override
  State<_VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<_VideoPlayerCard> {
  String? _localPath;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _prepareVideo();
  }

  Future<void> _prepareVideo() async {
    try {
      final sync = context.read<SyncService>();
      final localPath = await sync.getLocalMediaPath(widget.post.videoFile!);
      final localFile = File(localPath);
      if (await localFile.exists()) {
        _localPath = localFile.path;
      } else {
        final url =
            MediaUtils.buildMediaUrl(widget.feedState, widget.post.videoFile!);
        if (url == null) {
          if (mounted)
            setState(() {
              _hasError = true;
              _loading = false;
            });
          return;
        }
        final encryption = context.read<SyncService>().encryption;
        final dio = Dio();
        final response = await dio.get<List<int>>(url,
            options: Options(
                responseType: ResponseType.bytes,
                headers: widget.feedState.imageHeaders));
        if (response.data == null) throw Exception('Download failed');
        var bytes = response.data!;
        if (encryption != null && encryption.isEncryptionEnabled) {
          bytes = encryption.decryptBytes(Uint8List.fromList(bytes)).toList();
        }
        await localFile.writeAsBytes(bytes);
        sync.localMediaFiles.add(widget.post.videoFile!);
        _localPath = localFile.path;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    }
  }

  /// 获取视频封面 Widget（先用本地缩略图，再回退到占位）
  Widget _buildThumbnail(BuildContext context, ColorScheme cs) {
    final thumbName = widget.post.videoThumbnail;
    if (thumbName != null && thumbName.isNotEmpty) {
      final authBloc = context.read<AuthBloc>();
      final encryption = context.read<SyncService>().encryption;
      final url = MediaUtils.buildMediaUrl(widget.feedState, thumbName);
      return MediaUtils.buildImage(
        fileName: thumbName,
        imageUrl: url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        httpHeaders: widget.feedState.imageHeaders,
        encryption: encryption,
      );
    }
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.play_arrow_rounded, size: 56, color: cs.primary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _localPath == null
          ? null
          : () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          _VideoPlayerScreen(videoPath: _localPath!)));
            },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.black,
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: _buildThumbnail(context, cs)),
              if (_loading)
                const Center(
                    child: CircularProgressIndicator(color: Colors.white54))
              else if (_hasError)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.error_outline_rounded,
                          color: Colors.white70, size: 40),
                      SizedBox(height: 8),
                      Text('视频加载失败', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                )
              else
                Container(
                  decoration: const BoxDecoration(
                      color: Colors.black45, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(18),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 48),
                ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('点击播放',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 视频播放器（封面先行 + 横屏按钮 + 底部控制栏）
// ============================================================
class _VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  const _VideoPlayerScreen({required this.videoPath});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  bool _started = false;
  bool _showControls = true;
  bool _isPlaying = false;
  bool _openError = false;
  String _errorMsg = '';
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _playingSub = _player.stream.playing
        .listen((v) => mounted ? setState(() => _isPlaying = v) : null);
    _positionSub = _player.stream.position
        .listen((p) => mounted ? setState(() => _position = p) : null);
    _durationSub = _player.stream.duration
        .listen((d) => mounted ? setState(() => _duration = d) : null);
    // ★ iOS 兼容：补足 file:// scheme，避免 iOS 把本地路径当作字符串 URL 报错。
    final srcPath = widget.videoPath.startsWith('file://')
        ? widget.videoPath
        : 'file://${widget.videoPath}';
    _player.open(Media(srcPath)).catchError((e) {
      if (!mounted) return null;
      setState(() {
        _openError = true;
        _errorMsg = e.toString();
      });
      return null;
    });
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    // 恢复系统 UI（不强制横竖屏）
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _togglePlay() {
    if (!_started) {
      _started = true;
      _player.play();
    } else {
      _player.playOrPause();
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            // 视频区域：始终保持竖屏（不强制旋转）
            Center(
              child: _started
                  ? AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Video(
                          controller: _controller, controls: NoVideoControls),
                    )
                  : Container(
                      width: double.infinity,
                      color: Colors.black,
                      child: const Center(
                        child: Icon(Icons.play_circle_outline,
                            color: Colors.white70, size: 96),
                      ),
                    ),
            ),

            if (_showControls) ...[
              // 顶部：返回 + 视频信息 + 更多
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.info_outline_rounded,
                          color: Colors.white, size: 26),
                      tooltip: '视频信息',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_vert_rounded,
                          color: Colors.white, size: 26),
                      tooltip: '更多',
                    ),
                  ],
                ),
              ),

              // 中间播放按钮（未开始时显示）
              if (!_started)
                Center(
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(20),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 56),
                    ),
                  ),
                ),

              // 底部控制栏（播放/暂停/进度/时间/音量/横屏按钮）
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).padding.bottom + 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white30,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: _duration.inMilliseconds > 0
                              ? _position.inMilliseconds
                                  .toDouble()
                                  .clamp(0, _duration.inMilliseconds.toDouble())
                              : 0,
                          max: _duration.inMilliseconds > 0
                              ? _duration.inMilliseconds.toDouble()
                              : 1,
                          onChanged: (v) =>
                              _player.seek(Duration(milliseconds: v.toInt())),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _togglePlay,
                            icon: Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 32),
                          ),
                          const SizedBox(width: 4),
                          Text(_fmt(_position),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          const Spacer(),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.volume_up_rounded,
                                color: Colors.white, size: 22),
                            tooltip: '音量',
                          ),
                          IconButton(
                            onPressed: () async {
                              // 进入横屏（用户主动）
                              await SystemChrome.setPreferredOrientations([
                                DeviceOrientation.landscapeLeft,
                                DeviceOrientation.landscapeRight,
                              ]);
                            },
                            icon: const Icon(Icons.screen_rotation_rounded,
                                color: Colors.white, size: 22),
                            tooltip: '横屏播放',
                          ),
                          Text(_fmt(_duration),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 媒体轮播（图片）
// ============================================================
class _MediaCarousel extends StatefulWidget {
  final List<String> mediaFiles;
  final FeedState feedState;
  final double screenWidth;
  const _MediaCarousel(
      {required this.mediaFiles,
      required this.feedState,
      required this.screenWidth});

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasMultiple = widget.mediaFiles.length > 1;
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBar = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final availableHeight =
        screenHeight - statusBar - 56 - 120 - bottomSafe - 32;
    final imageHeight = availableHeight.clamp(200.0, screenHeight * 0.7);

    return Column(
      children: [
        SizedBox(
          height: imageHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaFiles.length,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, index) {
              final imageUrl = MediaUtils.buildMediaUrl(
                  widget.feedState, widget.mediaFiles[index]);
              final encryption = context.read<SyncService>().encryption;
              return GestureDetector(
                onTap: () => _openGallery(context, index),
                child: Container(
                  color: cs.surfaceContainerHighest.withOpacity(0.1),
                  child: MediaUtils.buildFullWidthImage(
                    fileName: widget.mediaFiles[index],
                    imageUrl: imageUrl,
                    screenWidth: widget.screenWidth,
                    fit: BoxFit.contain,
                    httpHeaders: widget.feedState.imageHeaders,
                    encryption: encryption,
                  ),
                ),
              );
            },
          ),
        ),
        if (hasMultiple)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.mediaFiles.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _currentIndex == index ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: _currentIndex == index
                        ? cs.primary
                        : cs.primary.withOpacity(0.3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  void _openGallery(BuildContext context, int initialIndex) {
    final imageUrls = widget.mediaFiles
        .map((f) => MediaUtils.buildMediaUrl(widget.feedState, f))
        .where((url) => url != null)
        .cast<String>()
        .toList();
    if (imageUrls.isEmpty) return;
    final encryption = context.read<SyncService>().encryption;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GalleryScreen(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          httpHeaders: widget.feedState.imageHeaders,
          encryption: encryption,
        ),
      ),
    );
  }
}

// ============================================================
// 图片查看器（返回+信息+更多+双击缩放+原图+底部 3/12+功能菜单）
// ============================================================
class _GalleryScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final Map<String, String> httpHeaders;
  final EncryptionService? encryption;
  const _GalleryScreen({
    required this.imageUrls,
    required this.initialIndex,
    this.httpHeaders = const {},
    this.encryption,
  });

  @override
  State<_GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<_GalleryScreen> {
  late int _currentIndex;
  late final PageController _pageController;
  /// 已加载的图片本地路径（key 为索引）
  final Map<int, String> _localPaths = {};
  final SyncService? _sync = MediaUtils.syncService;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    // ★ 进入全屏沉浸式：隐藏状态栏 + 导航栏（Android 关键修复）
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // 允许横屏 + 竖屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadImage(widget.initialIndex);
    _loadImage(widget.initialIndex - 1);
    _loadImage(widget.initialIndex + 1);
  }

  @override
  void dispose() {
    // 恢复系统 UI（回到详情页时不再沉浸式）
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _pageController.dispose();
    super.dispose();
  }

  /// 加载图片（优先本地，其次下载）
  Future<void> _loadImage(int index) async {
    if (index < 0 || index >= widget.imageUrls.length) return;
    if (_localPaths.containsKey(index)) return;

    try {
      final url = widget.imageUrls[index];
      final cleanFileName = Uri.parse(url).pathSegments.last;

      // 1. 优先本地文件
      if (_sync != null) {
        final localPath = await _sync.getLocalMediaPath(cleanFileName);
        final file = File(localPath);
        if (await file.exists()) {
          if (!mounted) return;
          setState(() => _localPaths[index] = localPath);
          return;
        }
      }

      // 2. 本地不存在：下载
      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(
            responseType: ResponseType.bytes, headers: widget.httpHeaders),
      );
      if (!mounted) return;
      if (response.data != null) {
        var data = response.data!;
        if (widget.encryption != null &&
            widget.encryption!.isEncryptionEnabled) {
          data = widget.encryption!
              .decryptBytes(Uint8List.fromList(data))
              .toList();
        }
        String savedPath = '';
        if (_sync != null && cleanFileName.isNotEmpty) {
          try {
            final localPath = await _sync.getLocalMediaPath(cleanFileName);
            await File(localPath).writeAsBytes(data);
            _sync.localMediaFiles.add(cleanFileName);
            savedPath = localPath;
          } catch (_) {}
        }
        if (!mounted) return;
        if (savedPath.isNotEmpty) {
          setState(() => _localPaths[index] = savedPath);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 图片区域
          PageView.builder(
            itemCount: widget.imageUrls.length,
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _loadImage(index - 1);
              _loadImage(index + 1);
            },
            itemBuilder: (context, index) {
              final localPath = _localPaths[index];
              if (localPath != null) {
                // ★ iOS 兼容：使用 Image.file + InteractiveViewer 替代 ExtendedImage。
                //   之前 ExtendedImage + GestureDetector 在 iOS 上容易拦截 tap 事件，
                //   导致点击图片不能触发全屏显示。现在用 InteractiveViewer（Flutter 内置）
                //   支持双指缩放、双击缩放，且不会拦截单次 tap。
                return InteractiveViewer(
                  minScale: 0.9,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.file(
                      File(localPath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.white54, size: 64),
                      ),
                    ),
                  ),
                );
              }
              _loadImage(index);
              return const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white54),
              );
            },
          ),

          // 顶部：返回 + 信息 + 更多
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 26),
                  ),
                ],
              ),
            ),
          ),

          // 底部：3 / 12
          if (widget.imageUrls.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 56, child: Text(label)),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _menuTile(
      BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }
}

/// 导出项（图片 / 视频）
class _ExportItem {
  final String fileName;
  final bool isVideo;
  final String displayName;
  const _ExportItem({
    required this.fileName,
    required this.isVideo,
    required this.displayName,
  });
}

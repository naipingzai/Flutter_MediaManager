import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../functionality/app_bloc.dart';
import '../functionality/auth_bloc.dart';
import '../functionality/feed_bloc.dart';
import '../models/post.dart';
import '../services/sync_service.dart';
import '../services/encryption_service.dart';
import 'export_helper.dart';
import 'media_utils.dart';
import 'create_post_screen.dart';

/// 帖子详情页
///
/// 布局：用户头像 + 昵称 → 完整内容 → 三列图片网格 → 视频卡片 → 标签 → 时间
class PostDetailScreen extends StatelessWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final feedState = context.read<FeedBloc>().state;

    final dt = post.createdAt;
    final timeStr =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 22),
            tooltip: '保存到系统',
            onPressed: () => _showExportSheet(context, post),
          ),
          IconButton(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => CreatePostScreen(editPost: post)),
              );
              if (result == true && context.mounted) {
                Navigator.pop(context, true);
              }
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
            // 用户头像 + 昵称 + 时间
            _buildUserHeader(context, cs, textTheme, timeStr),

            // 完整内容文本
            if (post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _buildRichContent(post.content, textTheme, cs),
              ),

            // 三列图片网格
            if (post.mediaFiles.isNotEmpty)
              _MediaGrid(
                mediaFiles: post.mediaFiles,
                feedState: feedState,
                screenWidth: screenWidth,
              ),

            // 视频播放卡片
            if (post.hasVideo)
              _VideoPlayerCard(
                feedState: feedState,
                post: post,
                screenWidth: screenWidth,
              ),

            // 标签
            if (post.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
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
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  /// 用户头像 + 昵称 + 时间
  Widget _buildUserHeader(
      BuildContext context, ColorScheme cs, TextTheme textTheme, String timeStr) {
    return BlocBuilder<AppBloc, AppState>(
      buildWhen: (prev, curr) =>
          prev.settings?.nickname != curr.settings?.nickname ||
          prev.settings?.avatarPath != curr.settings?.avatarPath,
      builder: (context, appState) {
        final settings = appState.settings;
        final avatarPath = settings?.avatarPath ?? '';
        final nickname = settings?.nickname ?? '媒体管理';
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primaryContainer,
                child: avatarPath.isNotEmpty
                    ? ClipOval(
                        child: Image.file(
                          File(avatarPath),
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.person_rounded,
                              size: 24,
                              color: cs.onPrimaryContainer),
                        ),
                      )
                    : Icon(Icons.person_rounded,
                        size: 24, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nickname,
                        style: textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(timeStr,
                        style: textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 内容文本（支持 #标签 高亮）
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

  /// 导出/分享菜单
  void _showExportSheet(BuildContext context, Post post) {
    final sync = context.read<SyncService>();
    final cs = Theme.of(context).colorScheme;
    final items = <_ExportItem>[];
    for (final fileName in post.mediaFiles) {
      items.add(_ExportItem(fileName: fileName, isVideo: false));
    }
    if (post.videoFile != null) {
      items.add(_ExportItem(fileName: post.videoFile!, isVideo: true));
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('该动态没有可导出的图片或视频'),
        behavior: SnackBarBehavior.floating,
      ));
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
              width: 36, height: 4,
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
                  Text('保存到系统 (${items.length})',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            ListTile(
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
                  final localPath = await sync.getLocalMediaPath(it.fileName);
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
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 删除确认弹窗
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
              context.read<FeedBloc>().add(FeedDeletePostEvent(post.id));
              Navigator.pop(ctx);
              await Future<void>.delayed(const Duration(milliseconds: 200));
              if (context.mounted) Navigator.pop(context);
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

/// 导出项
class _ExportItem {
  final String fileName;
  final bool isVideo;
  const _ExportItem({required this.fileName, required this.isVideo});
}

// ============================================================
// 三列图片网格（与 feed_screen 保持一致的网格布局）
// ============================================================
class _MediaGrid extends StatelessWidget {
  final List<String> mediaFiles;
  final FeedState feedState;
  final double screenWidth;

  const _MediaGrid({
    required this.mediaFiles,
    required this.feedState,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imageCount = mediaFiles.length;
    if (imageCount == 0) return const SizedBox.shrink();

    // 单图：大图显示
    if (imageCount == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: () => _openGallery(context, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildImage(context, mediaFiles[0], screenWidth - 32,
                  fit: BoxFit.fitWidth),
            ),
          ),
        ),
      );
    }

    // 多图：3列网格
    final crossAxisCount = imageCount == 2 ? 2 : 3;
    final spacing = 4.0;
    final imageSize =
        (screenWidth - 32 - spacing * (crossAxisCount - 1)) / crossAxisCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: 1.0,
        ),
        itemCount: imageCount > 9 ? 9 : imageCount,
        itemBuilder: (context, index) {
          if (index == 8 && imageCount > 9) {
            // 超过9张：最后一格显示剩余数量
            return GestureDetector(
              onTap: () => _openGallery(context, index),
              child: _buildMediaBox(
                context, cs,
                child: Stack(
                  children: [
                    _buildImage(context, mediaFiles[index], imageSize,
                        height: imageSize),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          '+${imageCount - 8}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return GestureDetector(
            onTap: () => _openGallery(context, index),
            child: _buildMediaBox(
              context, cs,
              child: _buildImage(context, mediaFiles[index], imageSize,
                  height: imageSize),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaBox(BuildContext context, ColorScheme cs,
      {required Widget child}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: child,
    );
  }

  Widget _buildImage(BuildContext context, String fileName, double width,
      {double? height, BoxFit fit = BoxFit.cover}) {
    final imageUrl = MediaUtils.buildMediaUrl(feedState, fileName);
    final encryption = context.read<SyncService>().encryption;
    return MediaUtils.buildImage(
      fileName: fileName,
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      httpHeaders: feedState.imageHeaders,
      encryption: encryption,
    );
  }

  void _openGallery(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GalleryScreen(
          mediaFiles: mediaFiles,
          feedState: feedState,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

// ============================================================
// 全屏图片查看器（支持左右滑动 + 双指缩放）
// ============================================================
class _GalleryScreen extends StatefulWidget {
  final List<String> mediaFiles;
  final FeedState feedState;
  final int initialIndex;

  const _GalleryScreen({
    required this.mediaFiles,
    required this.feedState,
    required this.initialIndex,
  });

  @override
  State<_GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<_GalleryScreen> {
  late int _currentIndex;
  late final PageController _pageController;
  final Map<int, String> _localPaths = {};
  final SyncService? _sync = MediaUtils.syncService;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadImage(int index) async {
    if (index < 0 || index >= widget.mediaFiles.length) return;
    if (_localPaths.containsKey(index)) return;

    try {
      final fileName = widget.mediaFiles[index];
      final imageUrl =
          MediaUtils.buildMediaUrl(widget.feedState, fileName);
      final headers = widget.feedState.imageHeaders;
      final encryption = _sync?.encryption;

      // 1. 优先本地文件
      if (_sync != null) {
        final localPath = await _sync.getLocalMediaPath(fileName);
        final file = File(localPath);
        if (await file.exists()) {
          if (!mounted) return;
          setState(() => _localPaths[index] = localPath);
          return;
        }
      }

      // 2. 本地不存在：从云端下载
      if (imageUrl == null || imageUrl.isEmpty) return;
      final dio = Dio();
      final response = await dio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes, headers: headers),
      );
      if (!mounted) return;
      if (response.data != null) {
        var data = Uint8List.fromList(response.data!);
        if (encryption != null) {
          data = encryption.decryptBytes(data);
        }
        String savedPath = '';
        if (_sync != null && fileName.isNotEmpty) {
          try {
            final localPath = await _sync.getLocalMediaPath(fileName);
            await File(localPath).writeAsBytes(data);
            _sync.localMediaFiles.add(fileName);
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
          PageView.builder(
            itemCount: widget.mediaFiles.length,
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _loadImage(index - 1);
              _loadImage(index + 1);
            },
            itemBuilder: (context, index) {
              final localPath = _localPaths[index];
              if (localPath != null) {
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
          // 返回按钮
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8, right: 8, bottom: 8,
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
          // 页码指示器
          if (widget.mediaFiles.length > 1)
            Positioned(
              left: 0, right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.mediaFiles.length}',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
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
  const _VideoPlayerCard({
    required this.feedState,
    required this.post,
    required this.screenWidth,
  });

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
        final url = MediaUtils.buildMediaUrl(widget.feedState, widget.post.videoFile!);
        if (url == null) {
          if (mounted) setState(() { _hasError = true; _loading = false; });
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
        if (encryption != null) {
          bytes = encryption.decryptBytes(Uint8List.fromList(bytes)).toList();
        }
        await localFile.writeAsBytes(bytes);
        sync.localMediaFiles.add(widget.post.videoFile!);
        _localPath = localFile.path;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _hasError = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _localPath == null ? null : () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => _VideoPlayerScreen(videoPath: _localPath!)));
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
                const Center(child: CircularProgressIndicator(color: Colors.white54))
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, ColorScheme cs) {
    final thumbName = widget.post.videoThumbnail;
    if (thumbName != null && thumbName.isNotEmpty) {
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
    _playingSub = _player.stream.playing.listen((v) {
      if (mounted) setState(() => _isPlaying = v);
    });
    _positionSub = _player.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSub = _player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    final srcPath = widget.videoPath.startsWith('file://')
        ? widget.videoPath
        : 'file://${widget.videoPath}';
    _player.open(Media(srcPath));
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
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
            Center(
              child: _started
                  ? AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Video(controller: _controller, controls: NoVideoControls),
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
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16, right: 16,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),
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
              Positioned(
                left: 0, right: 0,
                bottom: MediaQuery.of(context).padding.bottom + 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
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
                                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 4),
                          Text(_fmt(_position),
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const Spacer(),
                          Text(_fmt(_duration),
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
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

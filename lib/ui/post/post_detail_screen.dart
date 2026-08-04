import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:extended_image/extended_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../functionality/auth/auth_bloc.dart';
import '../../functionality/feed/feed_bloc.dart';
import '../../models/post.dart';
import '../../services/cache_service.dart';
import '../../services/encryption_service.dart';
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
          IconButton(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => CreatePostScreen(editPost: post)),
              );
              if (result == true && context.mounted) Navigator.pop(context, true);
            },
            icon: const Icon(Icons.edit_outlined, size: 22),
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
              _MediaCarousel(mediaFiles: post.mediaFiles, feedState: feedState, screenWidth: screenWidth),
            if (post.hasVideo)
              _VlcVideoPlayer(feedState: feedState, videoFileName: post.videoFile!, screenWidth: screenWidth),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(timeStr, style: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (post.tags.isNotEmpty)
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: post.tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(tag, style: textTheme.bodySmall?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w500)),
                      )).toList(),
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

  Widget _buildRichContent(String content, TextTheme textTheme, ColorScheme cs) {
    final regex = RegExp(r'#[^\s#]+');
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in regex.allMatches(content)) {
      if (match.start > lastEnd) spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      spans.add(TextSpan(text: content.substring(match.start + 1, match.end), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)));
      lastEnd = match.end;
    }
    if (lastEnd < content.length) spans.add(TextSpan(text: content.substring(lastEnd)));
    return SelectableText.rich(TextSpan(style: textTheme.bodyLarge?.copyWith(height: 1.8, fontSize: 16), children: spans));
  }

  void _confirmDelete(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, size: 40, color: cs.error),
        title: const Text('删除动态'),
        content: const Text('确定要删除这条动态吗？删除后无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () {
              context.read<FeedBloc>().add(FeedDeletePostEvent(post.id));
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('动态已删除')));
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 视频播放器 —— media_kit (全平台支持: Android/iOS/Linux/macOS/Windows)
// ============================================================
/// 视频预览卡片（点击后全屏播放）
class _VlcVideoPlayer extends StatefulWidget {
  final FeedState feedState;
  final String videoFileName;
  final double screenWidth;

  const _VlcVideoPlayer({required this.feedState, required this.videoFileName, required this.screenWidth});

  @override
  State<_VlcVideoPlayer> createState() => _VlcVideoPlayerState();
}

class _VlcVideoPlayerState extends State<_VlcVideoPlayer> {
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
      final cacheService = context.read<CacheService>();
      final localPath = await cacheService.getLocalMediaPath(widget.videoFileName);
      final localFile = File(localPath);

      if (await localFile.exists()) {
        _localPath = localFile.path;
      } else {
        final url = MediaUtils.buildMediaUrl(widget.feedState, widget.videoFileName);
        if (url == null) { if (mounted) setState(() { _hasError = true; _loading = false; }); return; }
        final authBloc = context.read<AuthBloc>();
        final encryption = authBloc.webDavService?.encryption;
        final dio = Dio();
        final response = await dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes, headers: widget.feedState.imageHeaders));
        if (response.data == null) throw Exception('Download failed');
        var bytes = response.data!;
        if (encryption != null && encryption.isEncryptionEnabled) {
          bytes = encryption.decryptBytes(Uint8List.fromList(bytes)).toList();
        }
        await localFile.writeAsBytes(bytes);
        cacheService.cachedFiles.add(widget.videoFileName);
        _localPath = localFile.path;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _hasError = true; _loading = false; });
    }
  }

  void _openFullscreen() {
    if (_localPath == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _FullscreenVideoPlayer(videoPath: _localPath!),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _openFullscreen,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.black,
        ),
        clipBehavior: Clip.antiAlias,
        child: _hasError
            ? Container(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, color: cs.error, size: 40),
                      const SizedBox(height: 8),
                      Text('视频加载失败', style: TextStyle(color: cs.error)),
                    ],
                  ),
                ),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(color: Colors.black),
                  ),
                  if (_loading)
                    const CircularProgressIndicator(color: Colors.white54)
                  else
                    Container(
                      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(20),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                    ),
                  Positioned(
                    bottom: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('全屏播放', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 全屏视频播放器（带进度条、快进快退、倍速）
class _FullscreenVideoPlayer extends StatefulWidget {
  final String videoPath;
  const _FullscreenVideoPlayer({required this.videoPath});

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  late final Player _player;
  late final VideoController _controller;
  bool _showControls = true;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _playingSub = _player.stream.playing.listen((v) { if (mounted) setState(() => _isPlaying = v); });
    _positionSub = _player.stream.position.listen((p) { if (mounted) setState(() => _position = p); });
    _durationSub = _player.stream.duration.listen((d) { if (mounted) setState(() => _duration = d); });
    _player.open(Media(widget.videoPath));
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }

  void _toggleSpeed() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final i = speeds.indexOf(_speed);
    _speed = speeds[(i + 1) % speeds.length];
    _player.setRate(_speed);
    setState(() {});
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
              child: Video(controller: _controller, controls: NoVideoControls),
            ),
            if (_showControls) ...[
              // 顶部返回按钮
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                ),
              ),
              // 中间播放/暂停
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => _player.seek(_position - const Duration(seconds: 10)),
                      icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: () => _player.playOrPause(),
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(16),
                        child: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white, size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      onPressed: () => _player.seek(_position + const Duration(seconds: 10)),
                      icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 36),
                    ),
                  ],
                ),
              ),
              // 底部进度条
              Positioned(
                left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 16,
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white30,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: _duration.inMilliseconds > 0
                            ? _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds.toDouble())
                            : 0,
                        max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1,
                        onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(_fmt(_position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const Spacer(),
                          GestureDetector(
                            onTap: _toggleSpeed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('${_speed}x', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const Spacer(),
                          Text(_fmt(_duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
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
// 媒体轮播（extended_image）
// ============================================================
class _MediaCarousel extends StatefulWidget {
  final List<String> mediaFiles;
  final FeedState feedState;
  final double screenWidth;

  const _MediaCarousel({required this.mediaFiles, required this.feedState, required this.screenWidth});

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

    // 计算可用高度：屏幕高度 - AppBar - 状态栏 - 底部安全区 - 文字区域
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBar = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    // 留出 AppBar(56) + 文字+标签(~120) + 底部(32) 的空间
    final availableHeight = screenHeight - statusBar - 56 - 120 - bottomSafe - 32;
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
              final imageUrl = MediaUtils.buildMediaUrl(widget.feedState, widget.mediaFiles[index]);
              final authBloc = context.read<AuthBloc>();
              final encryption = authBloc.webDavService?.encryption;
              return GestureDetector(
                onTap: () => _openGallery(context, index),
                child: Container(
                  color: cs.surfaceContainerHighest.withOpacity(0.1),
                  child: MediaUtils.buildFullWidthImage(
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
              children: List.generate(widget.mediaFiles.length, (index) =>
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _currentIndex == index ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: _currentIndex == index ? cs.primary : cs.primary.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openGallery(BuildContext context, int initialIndex) {
    final imageUrls = widget.mediaFiles
        .map((f) => MediaUtils.buildMediaUrl(widget.feedState, f))
        .where((url) => url != null).cast<String>().toList();
    if (imageUrls.isEmpty) return;

    final authBloc = context.read<AuthBloc>();
    final encryption = authBloc.webDavService?.encryption;

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _GalleryScreen(
        imageUrls: imageUrls, initialIndex: initialIndex,
        httpHeaders: widget.feedState.imageHeaders, encryption: encryption,
      ),
    ));
  }
}

/// 全屏图片查看（extended_image，双指缩放 + 左右滑动）
class _GalleryScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final Map<String, String> httpHeaders;
  final EncryptionService? encryption;

  const _GalleryScreen({
    required this.imageUrls, required this.initialIndex,
    this.httpHeaders = const {}, this.encryption,
  });

  @override
  State<_GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<_GalleryScreen> {
  late int _currentIndex;
  late final PageController _pageController;
  final Map<int, ImageProvider> _imageProviders = {};
  final CacheService? _cacheService = MediaUtils.cacheService;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadImage(widget.initialIndex);
    _loadImage(widget.initialIndex - 1);
    _loadImage(widget.initialIndex + 1);
  }

  Future<void> _loadImage(int index) async {
    if (index < 0 || index >= widget.imageUrls.length) return;
    if (_imageProviders.containsKey(index)) return;

    try {
      final url = widget.imageUrls[index];
      final cleanFileName = Uri.parse(url).pathSegments.last;

      // 本地缓存优先
      if (_cacheService != null) {
        final localPath = await _cacheService.getLocalMediaPath(cleanFileName);
        final file = File(localPath);
        if (await file.exists()) {
          if (!mounted) return;
          final bytes = await file.readAsBytes();
          setState(() => _imageProviders[index] = MemoryImage(bytes));
          return;
        }
      }

      // 网络下载
      final dio = Dio();
      final response = await dio.get<List<int>>(url,
        options: Options(responseType: ResponseType.bytes, headers: widget.httpHeaders),
      );
      if (!mounted) return;
      if (response.data != null) {
        var data = response.data!;
        if (widget.encryption != null && widget.encryption!.isEncryptionEnabled) {
          data = widget.encryption!.decryptBytes(Uint8List.fromList(data)).toList();
        }
        // 缓存到本地
        if (_cacheService != null && cleanFileName.isNotEmpty) {
          try {
            final localPath = await _cacheService.getLocalMediaPath(cleanFileName);
            await File(localPath).writeAsBytes(data);
            _cacheService.cachedFiles.add(cleanFileName);
          } catch (_) {}
        }
        if (!mounted) return;
        setState(() => _imageProviders[index] = MemoryImage(Uint8List.fromList(data)));
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 300) {
                Navigator.pop(context);
              }
            },
            child: PageView.builder(
              itemCount: widget.imageUrls.length,
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _loadImage(index - 1);
                _loadImage(index + 1);
              },
              itemBuilder: (context, index) {
                final provider = _imageProviders[index];
                if (provider != null) {
                  return ExtendedImage(
                    image: provider,
                    mode: ExtendedImageMode.gesture,
                    initGestureConfigHandler: (state) => GestureConfig(
                      minScale: 0.9,
                      animationMinScale: 0.7,
                      maxScale: 4.0,
                      animationMaxScale: 4.5,
                      speed: 1.0,
                      inertialSpeed: 100.0,
                      initialScale: 1.0,
                      inPageView: true,
                      initialAlignment: InitialAlignment.center,
                    ),
                  );
                }
                _loadImage(index);
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                );
              },
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16, right: 16, bottom: 8,
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
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Spacer(),
                  if (widget.imageUrls.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.imageUrls.length}',
                        style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  const Spacer(),
                  const SizedBox(width: 44),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

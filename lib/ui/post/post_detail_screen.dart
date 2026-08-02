import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';
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
          // 编辑按钮
          IconButton(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatePostScreen(editPost: post),
                ),
              );
              if (result == true && context.mounted) {
                Navigator.pop(context, true);
              }
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
            // 1. 文字内容
            if (post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: _buildRichContent(post.content, textTheme, cs),
              ),

            // 2. 媒体文件
            if (post.mediaFiles.isNotEmpty) ...[
              _MediaCarousel(
                mediaFiles: post.mediaFiles,
                feedState: feedState,
                screenWidth: screenWidth,
              ),
            ],

            if (post.hasVideo)
              _VideoPlayerWidget(
                feedState: feedState,
                videoFileName: post.videoFile!,
                screenWidth: screenWidth,
              ),

            // 3. 时间 + 标签
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间
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

                  // 标签
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
                                  borderRadius: BorderRadius.circular(16),
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

  Widget _buildRichContent(String content, TextTheme textTheme, ColorScheme cs) {
    final regex = RegExp(r'#[^\s#]+');
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in regex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: content.substring(match.start + 1, match.end),
        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }
    return SelectableText.rich(
      TextSpan(
        style: textTheme.bodyLarge?.copyWith(height: 1.8, fontSize: 16),
        children: spans,
      ),
    );
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () {
              context.read<FeedBloc>().add(FeedDeletePostEvent(post.id));
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('动态已删除')),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 视频播放器组件
// ============================================================
class _VideoPlayerWidget extends StatefulWidget {
  final FeedState feedState;
  final String videoFileName;
  final double screenWidth;

  const _VideoPlayerWidget({
    required this.feedState,
    required this.videoFileName,
    required this.screenWidth,
  });

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url =
        MediaUtils.buildMediaUrl(widget.feedState, widget.videoFileName);
    if (url == null) {
      setState(() => _hasError = true);
      return;
    }

    try {
      final authBloc = context.read<AuthBloc>();
      final encryption = authBloc.webDavService?.encryption;
      final headers = widget.feedState.imageHeaders;
      final isEncrypted = encryption != null && encryption.isEncryptionEnabled;

      if (isEncrypted) {
        // 加密视频：下载解密后写入临时文件播放
        final dio = Dio();
        final response = await dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes, headers: headers),
        );
        if (response.data == null) throw Exception('Download failed');
        final decrypted = encryption.decryptBytes(
            Uint8List.fromList(response.data!));
        final tempDir = await Directory.systemTemp.createTemp('video_');
        final tempFile = File('${tempDir.path}/${widget.videoFileName}');
        await tempFile.writeAsBytes(decrypted);
        _controller = VideoPlayerController.file(tempFile);
      } else {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          httpHeaders: headers,
        );
      }
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_hasError) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: cs.errorContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
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
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final aspect = _controller!.value.aspectRatio;
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.black,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: aspect,
              child: VideoPlayer(_controller!),
            ),
            // 播放/暂停控制
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _controller!.value.isPlaying
                        ? _controller!.pause()
                        : _controller!.play();
                    _showControls = false;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Icon(
                    _controller!.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
            // 进度条
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: cs.primary,
                  bufferedColor: cs.primary.withOpacity(0.3),
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaCarousel extends StatefulWidget {
  final List<String> mediaFiles;
  final FeedState feedState;
  final double screenWidth;

  const _MediaCarousel({
    required this.mediaFiles,
    required this.feedState,
    required this.screenWidth,
  });

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

    return Column(
      children: [
        Container(
          height: widget.screenWidth * 0.75,
          color: cs.surfaceContainerHighest.withOpacity(0.2),
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaFiles.length,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, index) {
              final imageUrl = MediaUtils.buildMediaUrl(
                  widget.feedState, widget.mediaFiles[index]);
              final authBloc = context.read<AuthBloc>();
              final encryption = authBloc.webDavService?.encryption;
              return GestureDetector(
                onTap: () => _openGallery(context, index),
                child: MediaUtils.buildFullWidthImage(
                  imageUrl: imageUrl,
                  screenWidth: widget.screenWidth,
                  fit: BoxFit.contain,
                  httpHeaders: widget.feedState.imageHeaders,
                  encryption: encryption,
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
              children: List.generate(
                widget.mediaFiles.length,
                (index) => AnimatedContainer(
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
        .where((url) => url != null)
        .cast<String>()
        .toList();
    if (imageUrls.isEmpty) return;

    final authBloc = context.read<AuthBloc>();
    final encryption = authBloc.webDavService?.encryption;

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

/// 全屏图片查看（双指缩放 + 左右滑动，支持加密 + 缓存）
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
  final Map<int, ImageProvider> _imageProviders = {};
  final Map<int, bool> _loadingImages = {};
  final CacheService? _cacheService = MediaUtils.cacheService;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadImage(widget.initialIndex);
    _preloadNeighbors(widget.initialIndex);
  }

  void _preloadNeighbors(int index) {
    _loadImage(index - 1);
    _loadImage(index + 1);
  }

  Future<void> _loadImage(int index) async {
    if (index < 0 || index >= widget.imageUrls.length) return;
    if (_imageProviders.containsKey(index) || _loadingImages[index] == true) return;
    _loadingImages[index] = true;

    try {
      final url = widget.imageUrls[index];
      // 提取文件名（去掉查询参数）
      final cleanFileName = Uri.parse(url).pathSegments.last;

      // 1. 尝试从缓存加载
      if (_cacheService != null && _cacheService.isCached(cleanFileName)) {
        final localPath = await _cacheService.getLocalPath(cleanFileName);
        final file = File(localPath);
        if (await file.exists()) {
          if (!mounted) return;
          final bytes = await file.readAsBytes();
          setState(() => _imageProviders[index] = MemoryImage(bytes));
          return;
        }
      }

      // 2. 从网络下载
      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: widget.httpHeaders,
        ),
      );
      if (!mounted) return;
      if (response.data != null) {
        var data = Uint8List.fromList(response.data!);
        // 解密
        if (widget.encryption != null && widget.encryption!.isEncryptionEnabled) {
          data = widget.encryption!.decryptBytes(data);
        }
        // 存入缓存（如果有缓存服务且文件名有效）
        if (_cacheService != null && _cacheService.enabled && cleanFileName.isNotEmpty) {
          try {
            final localPath = await _cacheService.getLocalPath(cleanFileName);
            await File(localPath).writeAsBytes(data);
          } catch (_) {}
        }
        if (!mounted) return;
        setState(() => _imageProviders[index] = MemoryImage(data));
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
          // 图片画廊（全屏，无 AppBar 遮挡）
          GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity!.abs() > 300) {
                Navigator.pop(context);
              }
            },
            child: PhotoViewGallery.builder(
              itemCount: widget.imageUrls.length,
              pageController: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _preloadNeighbors(index);
              },
              builder: (context, index) {
                final provider = _imageProviders[index];
                if (provider != null) {
                  return PhotoViewGalleryPageOptions(
                    imageProvider: provider,
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 4,
                    initialScale: PhotoViewComputedScale.contained,
                    heroAttributes: PhotoViewHeroAttributes(tag: 'gallery_$index'),
                  );
                }
                _loadImage(index);
                return PhotoViewGalleryPageOptions.customChild(
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                  initialScale: PhotoViewComputedScale.contained,
                );
              },
              scrollPhysics: const BouncingScrollPhysics(),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
          ),
          // 顶部关闭按钮 + 页码
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 28),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Spacer(),
                  if (widget.imageUrls.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
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
                  const Spacer(),
                  const SizedBox(width: 44), // 平衡左边
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

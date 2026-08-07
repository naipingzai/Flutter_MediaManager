import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../functionality/feed/feed_bloc.dart';
import '../../functionality/auth/auth_bloc.dart';
import '../../models/post.dart';
import '../../services/sync_service.dart';
import '../../utils/media_utils.dart';

/// 发布/编辑动态页面
class CreatePostScreen extends StatefulWidget {
  /// 编辑模式：传入已有 Post
  final Post? editPost;

  const CreatePostScreen({super.key, this.editPost});

  bool get isEditing => editPost != null;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final List<String> _imagePaths = [];
  final List<String> _tags = [];
  final List<String> _existingMediaFiles = [];
  String? _existingVideoFile;
  String? _videoPath;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    // 编辑模式：预填充
    if (widget.isEditing) {
      _contentController.text = widget.editPost!.content;
      _tags.addAll(widget.editPost!.tags);
      _existingMediaFiles.addAll(widget.editPost!.mediaFiles);
      _existingVideoFile = widget.editPost!.videoFile;
    }
    // 自动提取 #标签
    _contentController.addListener(() {
      _extractTagsFromContent(_contentController.text);
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_isPublishing) return;
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _imagePaths.addAll(picked.map((x) => x.path));
      });
    }
  }

  Future<void> _pickVideo() async {
    if (_isPublishing) return;
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      if (widget.isEditing) {
        setState(() => _existingVideoFile = null);
      }
      setState(() {
        _videoPath = picked.path;
      });
    }
  }

  /// 从内容中自动提取 #标签
  void _extractTagsFromContent(String content) {
    final regex = RegExp(r'#(\S+)');
    final matches = regex.allMatches(content);
    final extractedTags = matches.map((m) => m.group(1)!).toSet();
    setState(() {
      _tags.clear();
      _tags.addAll(extractedTags);
    });
  }

  void _removeTag(String tag) {
    if (_isPublishing) return;
    setState(() => _tags.remove(tag));
  }

  void _removeImage(int index) {
    if (_isPublishing) return;
    setState(() => _imagePaths.removeAt(index));
  }

  void _removeExistingMedia(int index) {
    if (_isPublishing) return;
    setState(() => _existingMediaFiles.removeAt(index));
  }

  Future<void> _publish() async {
    final content = _contentController.text.trim();
    if (content.isEmpty &&
        _imagePaths.isEmpty &&
        _existingMediaFiles.isEmpty &&
        _videoPath == null &&
        _existingVideoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入内容或添加图片')),
      );
      return;
    }

    setState(() => _isPublishing = true);

    if (widget.isEditing) {
      // 编辑模式
      context.read<FeedBloc>().add(FeedEditPostEvent(
            postId: widget.editPost!.id,
            content: content,
            tags: List.from(_tags),
            newLocalMediaPaths: List.from(_imagePaths),
            removedMediaFiles: widget.editPost!.mediaFiles
                .where((f) => !_existingMediaFiles.contains(f))
                .toList(),
          ));
    } else {
      // 创建模式
      context.read<FeedBloc>().add(FeedCreatePostEvent(
            content: content,
            localMediaPaths: List.from(_imagePaths),
            videoPath: _videoPath,
            tags: List.from(_tags),
          ));
    }
  }

  void _cancelPublishing() {
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isEditing = widget.isEditing;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑动态' : '发布动态'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _isPublishing ? null : _publish,
              child: _isPublishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? '保存' : '发布'),
            ),
          ),
        ],
      ),
      body: BlocConsumer<FeedBloc, FeedState>(
        listenWhen: (prev, curr) {
          // 只在发布完成后或出错时触发
          if (curr.status == FeedStatus.loaded && curr.uploadProgress >= 1.0)
            return true;
          if (curr.status == FeedStatus.error) return true;
          return false;
        },
        listener: (context, state) {
          if (_isPublishing &&
              state.status == FeedStatus.loaded &&
              state.uploadProgress >= 1.0) {
            _isPublishing = false;
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          } else if (_isPublishing && state.status == FeedStatus.error) {
            if (mounted) {
              setState(() => _isPublishing = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? '操作失败'),
                  backgroundColor: cs.error,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        },
        builder: (context, state) {
          final busy = _isPublishing ||
              state.status == FeedStatus.publishing ||
              state.status == FeedStatus.editing;
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 内容输入
                    TextField(
                      controller: _contentController,
                      enabled: !busy,
                      maxLines: 8,
                      minLines: 5,
                      decoration: InputDecoration(
                        hintText: '分享你的生活瞬间...',
                        border: InputBorder.none,
                        filled: false,
                      ),
                      style: textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 16),

                    // 已有媒体文件（编辑模式）
                    if (_existingMediaFiles.isNotEmpty) ...[
                      Text('已有图片',
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _buildExistingMediaGrid(cs, busy),
                      const SizedBox(height: 16),
                    ],

                    // 新增图片
                    if (_imagePaths.isNotEmpty) ...[
                      Text(isEditing ? '新增图片' : '图片',
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _buildImageGrid(cs, busy),
                      const SizedBox(height: 16),
                    ],

                    // 视频预览
                    if (_videoPath != null) ...[
                      Text('视频',
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color:
                                  cs.surfaceContainerHighest.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videocam_rounded,
                                      size: 36, color: cs.primary),
                                  const SizedBox(height: 4),
                                  Text(_videoPath!.split('/').last,
                                      style: textTheme.labelSmall,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ),
                          if (!_isPublishing)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _videoPath = null),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_existingVideoFile != null) ...[
                      Text('已有视频',
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color:
                                  cs.surfaceContainerHighest.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(Icons.videocam_rounded,
                                  size: 36, color: cs.primary),
                            ),
                          ),
                          if (!_isPublishing)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _existingVideoFile = null),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 添加媒体按钮
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: cs.outlineVariant.withOpacity(0.5)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: busy ? null : _pickImages,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined,
                                        size: 28, color: cs.primary),
                                    const SizedBox(height: 6),
                                    Text('图片',
                                        style: textTheme.bodySmall?.copyWith(
                                            color: cs.primary,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: cs.outlineVariant.withOpacity(0.5)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: busy ? null : _pickVideo,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  children: [
                                    Icon(Icons.videocam_outlined,
                                        size: 28, color: cs.primary),
                                    const SizedBox(height: 6),
                                    Text('视频',
                                        style: textTheme.bodySmall?.copyWith(
                                            color: cs.primary,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 标签输入（在内容中用 #标签 格式输入）
                    Text('标签',
                        style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600, color: cs.onSurface)),
                    const SizedBox(height: 4),
                    Text(
                      '在文字中输入 #标签名 自动识别，如：今天天气真好 #日常 #天气',
                      style: textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    if (_tags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => _removeTag(tag),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),

              // 上传进度遮罩
              if (busy)
                Positioned.fill(
                  child: ColoredBox(
                    color: cs.surface.withOpacity(0.85),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 56,
                              height: 56,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                color: cs.primary,
                                value: state.uploadProgress > 0
                                    ? state.uploadProgress
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              state.uploadStatusText ??
                                  (isEditing ? '正在保存...' : '正在发布...'),
                              style: textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${((state.uploadProgress.clamp(0.0, 1.0)) * 100).toStringAsFixed(0)}%',
                              style: textTheme.bodyMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: state.uploadProgress > 0
                                    ? state.uploadProgress
                                    : null,
                                minHeight: 4,
                                color: cs.primary,
                                backgroundColor: cs.primary.withOpacity(0.15),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: _cancelPublishing,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('取消'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 已有媒体文件网格（编辑模式，显示远程/缓存图片）
  Widget _buildExistingMediaGrid(ColorScheme cs, bool disabled) {
    final feedState = context.read<FeedBloc>().state;
    final authBloc = context.read<AuthBloc>();
    final encryption = context.read<SyncService>().encryption;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _existingMediaFiles.length,
      itemBuilder: (context, index) {
        final fileName = _existingMediaFiles[index];
        final imageUrl = MediaUtils.buildMediaUrl(feedState, fileName);

        return Stack(
          children: [
            Opacity(
              opacity: disabled ? 0.5 : 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MediaUtils.buildImage(
                  fileName: _existingMediaFiles[index],
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.circular(8),
                  httpHeaders: feedState.imageHeaders,
                  encryption: encryption,
                ),
              ),
            ),
            if (!disabled)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeExistingMedia(index),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildImageGrid(ColorScheme cs, bool disabled) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _imagePaths.length,
      itemBuilder: (context, index) {
        return Stack(
          children: [
            Opacity(
              opacity: disabled ? 0.5 : 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_imagePaths[index]),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            if (!disabled)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../functionality/auth/auth_bloc.dart';
import '../../functionality/feed/feed_bloc.dart';
import '../../models/post.dart';
import '../../services/sync_service.dart';
import '../../utils/media_utils.dart';
import '../post/post_detail_screen.dart';

/// 搜索页面
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  // 本地搜索/筛选状态，不影响 FeedBloc
  String _localQuery = '';
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    final state = context.read<FeedBloc>().state;
    if (state.status != FeedStatus.loaded || state.posts.isEmpty) {
      context.read<FeedBloc>().add(const FeedLoadEvent());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _localQuery = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _doSearch(value.trim());
    });
  }

  void _doSearch(String query) {
    setState(() => _localQuery = query);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _localQuery = '';
      _selectedTag = null;
    });
  }

  /// 本地过滤帖子（不修改 FeedBloc 状态）
  List<Post> _filterPosts(List<Post> posts) {
    var result = posts;
    if (_selectedTag != null && _selectedTag!.isNotEmpty) {
      result = result.where((p) => p.tags.contains(_selectedTag)).toList();
    }
    if (_localQuery.isNotEmpty) {
      final lower = _localQuery.toLowerCase();
      result = result.where((p) {
        return p.content.toLowerCase().contains(lower) ||
            p.tags.any((t) => t.toLowerCase().contains(lower));
      }).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 搜索栏
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: '搜索动态内容或标签...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _localQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: _clearSearch,
                        )
                      : null,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (v) => _doSearch(v.trim()),
              ),
            ),

            // 热门标签
            _buildHotTags(),

            const SizedBox(height: 4),

            // 搜索结果
            Expanded(
              child: BlocBuilder<FeedBloc, FeedState>(
                builder: (context, state) {
                  if (state.status == FeedStatus.loading &&
                      state.posts.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final isSearching =
                      _localQuery.isNotEmpty || _selectedTag != null;

                  if (!isSearching) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_rounded,
                              size: 56, color: cs.outline),
                          const SizedBox(height: 12),
                          Text('输入关键词或点击标签搜索动态',
                              style: textTheme.bodyLarge
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    );
                  }

                  final filteredPosts = _filterPosts(state.posts);
                  if (filteredPosts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 56, color: cs.outline),
                          const SizedBox(height: 12),
                          Text('没有找到相关动态',
                              style: textTheme.bodyLarge
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    );
                  }

                  return _buildPostList(filteredPosts, state, cs, textTheme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotTags() {
    return BlocBuilder<FeedBloc, FeedState>(
      builder: (context, state) {
        final allTags = <String>{};
        for (final post in state.posts) {
          allTags.addAll(post.tags);
        }
        if (allTags.isEmpty) return const SizedBox.shrink();

        final cs = Theme.of(context).colorScheme;

        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: allTags.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final tag = allTags.elementAt(index);
              final isSelected = _selectedTag == tag;
              return GestureDetector(
                onTap: () {
                  if (isSelected) {
                    _searchController.clear();
                    setState(() {
                      _selectedTag = null;
                      _localQuery = '';
                    });
                  } else {
                    _searchController.text = tag;
                    setState(() {
                      _selectedTag = tag;
                      _localQuery = tag;
                    });
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? cs.primary : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected
                        ? null
                        : Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPostList(List<Post> posts, FeedState feedState, ColorScheme cs,
      TextTheme textTheme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: posts.length,
      itemBuilder: (context, index) =>
          _SearchResultCard(post: posts[index], feedState: feedState),
    );
  }
}

/// 搜索结果卡片
class _SearchResultCard extends StatelessWidget {
  final Post post;
  final FeedState feedState;

  const _SearchResultCard({required this.post, required this.feedState});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasMedia = post.mediaFiles.isNotEmpty;
    final dt = post.createdAt;
    final timeStr =
        '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 缩略图
              if (hasMedia)
                Builder(builder: (ctx) {
                  final authBloc = ctx.read<AuthBloc>();
                  final encryption = context.read<SyncService>().encryption;
                  return MediaUtils.buildImage(
                    fileName: post.mediaFiles.first,
                    imageUrl:
                        MediaUtils.getFirstImageUrl(feedState, post.mediaFiles),
                    width: 72,
                    height: 72,
                    borderRadius: BorderRadius.circular(12),
                    httpHeaders: feedState.imageHeaders,
                    encryption: encryption,
                  );
                }),
              if (hasMedia) const SizedBox(width: 12),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.content.isNotEmpty)
                      Text(
                        post.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                    const SizedBox(height: 6),
                    if (post.tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: post.tags
                            .take(3)
                            .map((tag) => Text(tag,
                                style: textTheme.labelSmall
                                    ?.copyWith(color: cs.primary)))
                            .toList(),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(timeStr,
                            style: textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                        if (post.mediaFiles.length > 1) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.photo_library_outlined,
                              size: 12, color: cs.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text('${post.mediaFiles.length}',
                              style: textTheme.labelSmall),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../functionality/auth_bloc.dart';
import 'dart:io';
import '../functionality/feed_bloc.dart';
import '../functionality/app_bloc.dart';
import '../models/post.dart';
import '../services/sync_service.dart';
import 'media_utils.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

/// 首页 - 动态信息流
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FeedBloc>().add(const FeedLoadEvent());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: BlocConsumer<FeedBloc, FeedState>(
        listenWhen: (prev, curr) =>
            prev.uploadProgress != curr.uploadProgress ||
            prev.uploadStatusText != curr.uploadStatusText ||
            (prev.status != FeedStatus.loaded &&
                curr.status == FeedStatus.loaded),
        listener: (context, state) {
          if (state.uploadStatusText == '发布完成' ||
              state.uploadStatusText == '编辑完成') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.uploadStatusText!),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () async {
              context.read<FeedBloc>().add(const FeedLoadEvent());
              await context
                  .read<FeedBloc>()
                  .stream
                  .firstWhere((s) => s.status != FeedStatus.loading);
            },
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context, state, cs, textTheme),
                if (state.filterStartDate != null ||
                    state.filterEndDate != null)
                  _buildDateFilterChip(context, state, cs, textTheme),
                _buildContent(context, state, cs, textTheme),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
        },
        icon: const Icon(Icons.edit_location_alt_outlined, size: 20),
        label: const Text('发布'),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, FeedState state,
      ColorScheme cs, TextTheme textTheme) {
    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: true,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: cs.surface,
      surfaceTintColor: cs.surfaceTint,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '媒体管理',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (state.filteredPosts.isNotEmpty)
                Text(
                  '${state.filteredPosts.length} 条记录',
                  style: textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        // 同步按钮
        _SyncButton(),
        PopupMenuButton<FeedSortMode>(
          icon: Icon(Icons.sort_rounded, size: 22, color: cs.onSurfaceVariant),
          tooltip: '排序',
          onSelected: (mode) {
            context.read<FeedBloc>().add(FeedSortChangedEvent(mode));
          },
          itemBuilder: (context) => [
            _sortItem(FeedSortMode.newest, '最新优先', Icons.access_time_rounded,
                state, cs),
            _sortItem(
                FeedSortMode.oldest, '最早优先', Icons.history_rounded, state, cs),
            _sortItem(FeedSortMode.contentAsc, '内容 A-Z',
                Icons.sort_by_alpha_rounded, state, cs),
            _sortItem(FeedSortMode.contentDesc, '内容 Z-A',
                Icons.sort_by_alpha_rounded, state, cs),
            _sortItem(FeedSortMode.mediaCountDesc, '媒体数',
                Icons.photo_library_rounded, state, cs),
          ],
        ),
        IconButton(
          onPressed: () => _showDatePicker(context, state),
          icon: Icon(
            state.filterStartDate != null
                ? Icons.date_range_rounded
                : Icons.calendar_today_outlined,
            size: 22,
            color: state.filterStartDate != null
                ? cs.primary
                : cs.onSurfaceVariant,
          ),
          tooltip: '日期筛选',
        ),
        if (state.filterStartDate != null)
          IconButton(
            onPressed: () =>
                context.read<FeedBloc>().add(const FeedClearFilterEvent()),
            icon:
                Icon(Icons.filter_alt_off_rounded, color: cs.primary, size: 22),
            tooltip: '清除筛选',
          ),
        IconButton(
          onPressed: () => context.read<FeedBloc>().add(const FeedLoadEvent()),
          icon: const Icon(Icons.refresh_rounded, size: 22),
          tooltip: '刷新',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  PopupMenuItem<FeedSortMode> _sortItem(FeedSortMode mode, String label,
      IconData icon, FeedState state, ColorScheme cs) {
    final isSelected = state.sortMode == mode;
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isSelected ? cs.primary : null),
          const SizedBox(width: 12),
          Text(label),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check_rounded, size: 16, color: cs.primary),
          ],
        ],
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context, FeedState state) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: state.filterStartDate != null
          ? DateTimeRange(
              start: state.filterStartDate!, end: state.filterEndDate!)
          : null,
    );
    if (picked != null && mounted) {
      context.read<FeedBloc>().add(FeedDateFilterEvent(
            startDate: picked.start,
            endDate: picked.end,
          ));
    }
  }

  Widget _buildDateFilterChip(BuildContext context, FeedState state,
      ColorScheme cs, TextTheme textTheme) {
    final start = state.filterStartDate;
    final end = state.filterEndDate;
    final label = start != null && end != null
        ? '${start.month}/${start.day} - ${end.month}/${end.day}'
        : '日期筛选';
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range_rounded, size: 18, color: cs.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onTertiaryContainer,
                    fontWeight: FontWeight.w500,
                  )),
            ),
            GestureDetector(
              onTap: () =>
                  context.read<FeedBloc>().add(const FeedDateFilterEvent()),
              child: Icon(Icons.close_rounded,
                  size: 18, color: cs.onTertiaryContainer),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, FeedState state, ColorScheme cs,
      TextTheme textTheme) {
    if (state.status == FeedStatus.loading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.status == FeedStatus.error) {
      final errMsg = state.errorMessage ?? '加载失败';
      final isAuthError = errMsg.contains('会话已过期');
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    isAuthError
                        ? Icons.lock_open_outlined
                        : Icons.cloud_off_rounded,
                    size: 48,
                    color: cs.error,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isAuthError ? '会话已过期' : '加载失败',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(errMsg,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 20),
                if (isAuthError)
                  FilledButton.icon(
                    onPressed: () {
                      context.read<AuthBloc>().add(const AuthLogoutEvent());
                    },
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('重新登录'),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          context.read<AuthBloc>().add(const AuthLogoutEvent());
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('切换账号'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            context.read<FeedBloc>().add(const FeedLoadEvent()),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }
    if (state.filteredPosts.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.auto_awesome_rounded,
                    size: 48, color: cs.primary),
              ),
              const SizedBox(height: 20),
              Text('还没有动态',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('点击右下角按钮发布你的第一条动态',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 80),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _PostCard(
            post: state.filteredPosts[index],
            state: state,
          ),
          childCount: state.filteredPosts.length,
        ),
      ),
    );
  }
}

/// 同步状态按钮（按 guide.skill 第一节）
class _SyncButton extends StatefulWidget {
  @override
  State<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<_SyncButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final cs = Theme.of(context).colorScheme;
    final auth = context.read<AuthBloc>().state;

    // 已登录才显示
    if (auth.status != AuthStatus.authenticated) return const SizedBox.shrink();

    final status = sync.syncStatus;
    if (status == SyncStatus.syncing) {
      _spinController.repeat();
    } else {
      _spinController.stop();
    }

    final (IconData icon, Color iconColor, String label) = switch (status) {
      SyncStatus.idle => (Icons.cloud_outlined, cs.onSurfaceVariant, '同步'),
      SyncStatus.syncing => (Icons.sync_rounded, cs.primary, '同步中'),
      SyncStatus.success => (Icons.cloud_done_rounded, Colors.green, '同步'),
      SyncStatus.failed => (Icons.cloud_off_rounded, cs.error, '同步'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _onTap(context, sync, status),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                status == SyncStatus.syncing
                    ? RotationTransition(
                        turns: _spinController,
                        child: Icon(icon, size: 16, color: iconColor),
                      )
                    : Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: iconColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(
      BuildContext context, SyncService sync, SyncStatus status) async {
    switch (status) {
      case SyncStatus.syncing:
        _showSyncingDialog(context, sync);
        break;
      case SyncStatus.success:
        _showSuccessSummary(context, sync);
        break;
      case SyncStatus.failed:
        _showFailureDialog(context, sync);
        break;
      case SyncStatus.idle:
        await _triggerSync(context);
        break;
    }
  }

  Future<void> _triggerSync(BuildContext context) async {
    final feedBloc = context.read<FeedBloc>();
    final appBloc = context.read<AppBloc>();
    final settings = appBloc.state.settings;
    final ok = await feedBloc.performManualSync(
      nickname: settings?.nickname,
      avatarPath: settings?.avatarPath,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '同步完成' : '同步失败'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSyncingDialog(BuildContext context, SyncService sync) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.sync_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('正在同步'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sync.currentFileName != null)
              Text(sync.currentFileName!,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: sync.totalToSync > 0
                    ? sync.syncedCount / sync.totalToSync
                    : null,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text('${sync.syncedCount} / ${sync.totalToSync}'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('隐藏')),
        ],
      ),
    );
  }

  void _showSuccessSummary(BuildContext context, SyncService sync) {
    final summary = sync.lastSummary;
    if (summary == null) return;
    final timeStr = '${summary.lastSyncTime.year}-'
        '${summary.lastSyncTime.month.toString().padLeft(2, '0')}-'
        '${summary.lastSyncTime.day.toString().padLeft(2, '0')} '
        '${summary.lastSyncTime.hour.toString().padLeft(2, '0')}:'
        '${summary.lastSyncTime.minute.toString().padLeft(2, '0')}:'
        '${summary.lastSyncTime.second.toString().padLeft(2, '0')}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('最近同步'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('时间：$timeStr'),
            const SizedBox(height: 8),
            Text('上传：${summary.uploadedCount} 个文件'),
            Text('下载：${summary.downloadedCount} 个文件'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  void _showFailureDialog(BuildContext context, SyncService sync) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('同步失败'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('失败原因'),
            const SizedBox(height: 4),
            SelectableText(
              sync.syncError ?? '未知错误',
              style: const TextStyle(fontSize: 13),
            ),
            if (sync.syncErrorStatusCode != null) ...[
              const SizedBox(height: 8),
              Text('服务器返回 ${sync.syncErrorStatusCode}'),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }
}

/// 动态卡片
class _PostCard extends StatelessWidget {
  final Post post;
  final FeedState state;

  const _PostCard({required this.post, required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasContent = post.content.trim().isNotEmpty;
    final hasMedia = post.mediaFiles.isNotEmpty || post.hasVideo;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            BlocBuilder<AppBloc, AppState>(
              buildWhen: (prev, curr) =>
                  prev.settings?.nickname != curr.settings?.nickname ||
                  prev.settings?.avatarPath != curr.settings?.avatarPath,
              builder: (context, appState) {
                final settings = appState.settings;
                final avatarPath = settings?.avatarPath ?? '';
                final nickname = settings?.nickname ?? '媒体管理';
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: cs.primaryContainer,
                        child: avatarPath.isNotEmpty
                            ? ClipOval(
                                child: Image.file(
                                  File(avatarPath),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                      Icons.person_rounded,
                                      size: 22,
                                      color: cs.onPrimaryContainer),
                                ),
                              )
                            : Icon(Icons.person_rounded,
                                size: 22, color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nickname,
                              style: textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _fmtTime(post.createdAt),
                              style: textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (hasContent)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text.rich(
                  TextSpan(
                    children: _buildContentSpans(post.content, textTheme, cs),
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
            if (hasMedia)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _MediaGrid(post: post, state: state),
              ),
            if (post.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: post.tags
                      .map((tag) => GestureDetector(
                            onTap: () {
                              context
                                  .read<AppBloc>()
                                  .add(const AppNavigationChangedEvent(1));
                              Future.delayed(const Duration(milliseconds: 200),
                                  () {
                                if (context.mounted) {
                                  context
                                      .read<FeedBloc>()
                                      .add(FeedFilterByTagEvent(tag));
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: cs.primary.withOpacity(0.2),
                                    width: 0.5),
                              ),
                              child: Text(tag,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.primary,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ))
                      .toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(
                children: [
                  if (post.hasVideo) ...[
                    Icon(Icons.videocam_rounded, size: 14, color: cs.primary),
                    const SizedBox(width: 4),
                    Text('视频',
                        style:
                            textTheme.labelSmall?.copyWith(color: cs.primary)),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<TextSpan> _buildContentSpans(
      String content, TextTheme textTheme, ColorScheme cs) {
    final regex = RegExp(r'#(\S+)');
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in regex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }
    return spans;
  }

  String _fmtTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// 媒体网格（按 guide.skill 第二节：视频封面/时长，第三节：图片缩略图）
class _MediaGrid extends StatelessWidget {
  final Post post;
  final FeedState state;

  const _MediaGrid({required this.post, required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final allMedia = post.mediaFiles;
    final hasVideo = post.hasVideo;
    final imageCount = allMedia.length;
    int totalMedia = imageCount + (hasVideo ? 1 : 0);
    final displayCount = totalMedia > 9 ? 9 : totalMedia;
    final hasMore = totalMedia > 9;

    if (imageCount == 0 && !hasVideo) return const SizedBox.shrink();

    // 单个媒体
    if (displayCount == 1 && !hasMore) {
      final maxW = screenWidth * 0.7;
      if (hasVideo && imageCount == 0) {
        return _buildVideoOnlyCard(context, cs, textTheme, maxW);
      }
      return Align(
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: BoxConstraints(maxWidth: maxW),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _buildImage(context, allMedia.first, maxW,
                height: maxW, fit: BoxFit.cover),
          ),
        ),
      );
    }

    // 多张：3 列网格，每个独立圆角 16
    final crossAxisCount = displayCount == 2 ? 2 : 3;
    final spacing = 6.0;
    final imageSize =
        (screenWidth - 32 - spacing * (crossAxisCount - 1)) / crossAxisCount;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 1.0,
      ),
      itemCount: displayCount,
      itemBuilder: (context, index) {
        if (hasVideo && index == 0) {
          return _buildMediaBox(
            context,
            cs,
            child: Stack(
              children: [
                Positioned.fill(
                  child: post.videoThumbnail != null &&
                          post.videoThumbnail!.isNotEmpty
                      ? _buildImage(context, post.videoThumbnail!, imageSize,
                          height: imageSize, fit: BoxFit.cover)
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                cs.primary.withOpacity(0.08),
                                cs.primary.withOpacity(0.18),
                              ],
                            ),
                          ),
                        ),
                ),
                Container(
                  color: Colors.black26,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                          color: Colors.white70, shape: BoxShape.circle),
                      child: Icon(Icons.play_arrow_rounded,
                          size: 28, color: cs.primary),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final imageIndex = hasVideo ? index - 1 : index;
        if (imageIndex >= imageCount) return const SizedBox.shrink();

        if (hasMore && index == 8) {
          return _buildMediaBox(
            context,
            cs,
            child: Stack(
              children: [
                _buildImage(context, allMedia[imageIndex], imageSize,
                    height: imageSize, fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      '+${totalMedia - 8}',
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
          );
        }

        return _buildMediaBox(
          context,
          cs,
          child: _buildImage(context, allMedia[imageIndex], imageSize,
              height: imageSize, fit: BoxFit.cover),
        );
      },
    );
  }

  Widget _buildVideoOnlyCard(
      BuildContext context, ColorScheme cs, TextTheme textTheme, double maxW) {
    final thumbnail = post.videoThumbnail;
    final hasThumb = thumbnail != null && thumbnail.isNotEmpty;
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hasThumb)
                _buildImage(context, thumbnail, maxW, fit: BoxFit.cover),
              Container(
                decoration: const BoxDecoration(
                    color: Colors.black38, shape: BoxShape.circle),
                padding: const EdgeInsets.all(10),
                child: const Icon(Icons.play_arrow_rounded,
                    size: 28, color: Colors.white),
              ),
            ],
          ),
        ),
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
    final imageUrl = MediaUtils.buildMediaUrl(state, fileName);
    final authBloc = context.read<AuthBloc>();
    final encryption = context.read<SyncService>().encryption;
    return MediaUtils.buildImage(
      fileName: fileName,
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      httpHeaders: state.imageHeaders,
      encryption: encryption,
    );
  }
}

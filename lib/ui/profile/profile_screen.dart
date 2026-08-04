import 'dart:io';
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../functionality/feed/feed_bloc.dart';
import '../../functionality/home/app_bloc.dart';
import '../../functionality/auth/auth_bloc.dart';
import '../../services/cache_service.dart';
import '../../models/settings.dart' show ThemeMode;
import '../../services/log_service.dart';
import '../log/log_viewer_screen.dart';

/// 个人中心页面
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, appState) {
          return BlocBuilder<FeedBloc, FeedState>(
            builder: (context, feedState) {
              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    centerTitle: false,
                    title: Text('我的',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                  // 个人信息区（可编辑）
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: GestureDetector(
                        onTap: () => _editProfile(
                            context, appState, cs, textTheme),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: cs.primaryContainer,
                              child: appState.settings?.avatarPath !=
                                          null &&
                                      appState
                                          .settings!.avatarPath.isNotEmpty
                                  ? ClipOval(
                                      child: Image.file(
                                        File(
                                            appState.settings!.avatarPath),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Icon(Icons.person_rounded,
                                                size: 44,
                                                color:
                                                    cs.onPrimaryContainer),
                                      ),
                                    )
                                  : Icon(Icons.person_rounded,
                                      size: 44,
                                      color: cs.onPrimaryContainer),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              appState.settings?.nickname ?? '生活记录者',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '点击编辑个人资料',
                              style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // 设置区标题
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: Text(
                        '设置',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),

                  // 设置项 - 常用功能
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                              color: cs.outlineVariant.withOpacity(0.4)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            _CacheTile(),
                            _SyncIntervalTile(),
                            _RawDataTile(),
                            Divider(
                                height: 1,
                                indent: 56,
                                color: cs.outlineVariant.withOpacity(0.2)),

                            _ThemeTile(),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // 设置项 - 工具与信息
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                              color: cs.outlineVariant.withOpacity(0.4)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            _SettingTile(
                              icon: Icons.description_outlined,
                              label: '查看日志',
                              subtitle:
                                  '${context.read<LogService>().logs.length} 条',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const LogViewerScreen(),
                                  ),
                                );
                              },
                            ),
                            Divider(
                                height: 1,
                                indent: 56,
                                color: cs.outlineVariant.withOpacity(0.2)),
                            _SettingTile(
                              icon: Icons.content_copy_rounded,
                              label: '复制日志',
                              subtitle: '导出日志到剪贴板',
                              onTap: () {
                                final logService =
                                    context.read<LogService>();
                                final text = logService.export();
                                Clipboard.setData(
                                    ClipboardData(text: text));
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text('日志已复制到剪贴板'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                            Divider(
                                height: 1,
                                indent: 56,
                                color: cs.outlineVariant.withOpacity(0.2)),
                            _SettingTile(
                              icon: Icons.info_rounded,
                              label: '关于',
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    icon: Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 48,
                                        color: cs.primary),
                                    title: const Text('生活动态'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('版本 1.0.0',
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                    color: cs
                                                        .onSurfaceVariant)),
                                        const SizedBox(height: 12),
                                        const Text(
                                            '记录美好生活，分享精彩瞬间。\n数据存储在 WebDAV 服务器上，支持多端同步。',
                                            textAlign:
                                                TextAlign.center),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx),
                                        child: const Text('确定'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // 设置项 - 危险操作
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                              color: cs.outlineVariant.withOpacity(0.4)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            _SettingTile(
                              icon: Icons.delete_sweep_rounded,
                              label: '清除云端数据',
                              subtitle: '删除 WebDAV 上所有 APP 数据',
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                icon: Icon(Icons.warning_rounded,
                                    size: 48, color: cs.error),
                                title: const Text('清除云端数据'),
                                content: const Text(
                                    '确定要删除 WebDAV 服务器上所有 APP 数据吗？\n\n'
                                    '包括：\n'
                                    '• 所有动态（data.json）\n'
                                    '• 所有媒体文件（图片/视频）\n'
                                    '• 原始数据副本\n\n'
                                    '此操作不可恢复！'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: cs.error),
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      final webDavService = context
                                          .read<AuthBloc>()
                                          .webDavService;
                                      if (webDavService != null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content: Text('正在清除数据...'),
                                          behavior:
                                              SnackBarBehavior.floating,
                                        ));
                                        await webDavService.clearAllData();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                            content: Text('云端数据已清除'),
                                            behavior:
                                                SnackBarBehavior.floating,
                                          ));
                                          // 重新加载
                                          context
                                              .read<FeedBloc>()
                                              .add(const FeedLoadEvent());
                                        }
                                      }
                                    },
                                    child: const Text('确认删除'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Divider(
                            height: 1,
                            indent: 56,
                            color: cs.outlineVariant.withOpacity(0.2)),
                        _SettingTile(
                          icon: Icons.logout_rounded,
                          label: '退出登录',
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('退出登录'),
                                    content:
                                        const Text('确定要退出登录吗？'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx),
                                        child: const Text('取消'),
                                      ),
                                      FilledButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          context
                                              .read<AuthBloc>()
                                              .add(
                                                  const AuthLogoutEvent());
                                        },
                                        child: const Text('确定'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// 编辑个人资料
  void _editProfile(BuildContext context, AppState appState,
      ColorScheme cs, TextTheme textTheme) {
    final nicknameController = TextEditingController(
        text: appState.settings?.nickname ?? '生活记录者');
    String avatarPath = appState.settings?.avatarPath ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
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
                Text('编辑个人资料',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                // 头像
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      setModalState(() => avatarPath = picked.path);
                    }
                  },
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: cs.primaryContainer,
                    child: avatarPath.isNotEmpty
                        ? ClipOval(
                            child: Image.file(
                              File(avatarPath),
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(Icons.camera_alt_rounded,
                            size: 28, color: cs.onPrimaryContainer),
                  ),
                ),
                const SizedBox(height: 8),
                Text('点击更换头像',
                    style: textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 16),
                // 昵称
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: nicknameController,
                    decoration: const InputDecoration(
                      labelText: '昵称',
                      hintText: '输入你的昵称',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // 保存按钮
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final settings = appState.settings;
                        if (settings == null) return;
                        final nickname =
                            nicknameController.text.trim().isEmpty
                                ? '生活记录者'
                                : nicknameController.text.trim();

                        // 上传头像到 WebDAV
                        String? avatarFileName;
                        if (avatarPath.isNotEmpty &&
                            avatarPath != settings.avatarPath) {
                          final webDavService =
                              context.read<AuthBloc>().webDavService;
                          if (webDavService != null) {
                            avatarFileName =
                                await webDavService.uploadAvatar(avatarPath);
                          }
                        }

                        // 保存用户资料到 WebDAV
                        final webDavService =
                            context.read<AuthBloc>().webDavService;
                        if (webDavService != null) {
                          await webDavService.saveUserProfile({
                            'nickname': nickname,
                            'avatarFileName': avatarFileName ?? '',
                          });
                        }

                        // 更新本地设置
                        final newSettings = settings.copyWith(
                          nickname: nickname,
                          avatarPath: avatarPath,
                        );
                        context
                            .read<AppBloc>()
                            .add(AppSettingsUpdatedEvent(newSettings));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('个人资料已更新'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text('保存'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }


}

/// 主题切换设置项
class _ThemeTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final mode = state.settings?.themeMode;
        final modeLabel = switch (mode) {
          ThemeMode.light => '浅色',
          ThemeMode.dark => '深色',
          _ => '跟随系统',
        };
        return ListTile(
          leading: Icon(
            mode == ThemeMode.dark
                ? Icons.dark_mode_rounded
                : mode == ThemeMode.light
                    ? Icons.light_mode_rounded
                    : Icons.brightness_auto_rounded,
            color: cs.onSurfaceVariant,
          ),
          title: Text('主题模式', style: textTheme.bodyLarge),
          subtitle: Text(modeLabel, style: textTheme.bodySmall),
          trailing: Icon(Icons.chevron_right_rounded,
              size: 20, color: cs.onSurfaceVariant),
          onTap: () => _showThemePicker(context, mode),
        );
      },
    );
  }

  void _showThemePicker(BuildContext context, ThemeMode? current) {
    final cs = Theme.of(context).colorScheme;
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
            Text('主题模式',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.brightness_auto_rounded),
              title: const Text('跟随系统'),
              trailing: current == null || current == ThemeMode.system
                  ? Icon(Icons.check_rounded, color: cs.primary)
                  : null,
              onTap: () {
                context
                    .read<AppBloc>()
                    .add(AppThemeChangedEvent(ThemeMode.system));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode_rounded),
              title: const Text('浅色模式'),
              trailing: current == ThemeMode.light
                  ? Icon(Icons.check_rounded, color: cs.primary)
                  : null,
              onTap: () {
                context
                    .read<AppBloc>()
                    .add(AppThemeChangedEvent(ThemeMode.light));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_rounded),
              title: const Text('深色模式'),
              trailing: current == ThemeMode.dark
                  ? Icon(Icons.check_rounded, color: cs.primary)
                  : null,
              onTap: () {
                context
                    .read<AppBloc>()
                    .add(AppThemeChangedEvent(ThemeMode.dark));
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 缓存设置项（带开关和同步进度）
class _CacheTile extends StatefulWidget {
  const _CacheTile();

  @override
  State<_CacheTile> createState() => _CacheTileState();
}

class _CacheTileState extends State<_CacheTile> {
  @override
  void initState() {
    super.initState();
    final cacheService = context.read<CacheService>();
    cacheService.onSyncStateChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cacheService = context.read<CacheService>();
    final appBloc = context.read<AppBloc>();
    final isEnabled = cacheService.enabled;

    String subtitle = '关闭';
    if (isEnabled) {
      switch (cacheService.syncStatus) {
        case SyncStatus.syncing:
          subtitle =
              '同步中 ${cacheService.syncedCount}/${cacheService.totalToSync}';
          break;
        case SyncStatus.completed:
          subtitle = '已同步 ${cacheService.cachedFiles.length} 个文件';
          break;
        case SyncStatus.error:
          subtitle = '同步出错';
          break;
        default:
          subtitle = '已开启';
      }
    }

    return Column(
      children: [
        ListTile(
          leading: Icon(
            isEnabled
                ? Icons.cloud_download_rounded
                : Icons.cloud_off_outlined,
            color: cs.onSurfaceVariant,
          ),
          title: const Text('数据同步'),
          subtitle: Text(isEnabled ? subtitle : '关闭'),
          trailing: Switch(
            value: isEnabled,
            onChanged: (value) {
              final settings = appBloc.state.settings;
              if (settings == null) return;
              final newSettings = settings.copyWith(cacheEnabled: value);
              appBloc.add(AppSettingsUpdatedEvent(newSettings));
              cacheService.setEnabled(value);
              if (value) {
                final feedState = context.read<FeedBloc>().state;
                final allFiles = <String>[];
                for (final post in feedState.posts) {
                  allFiles.addAll(post.mediaFiles);
                }
                cacheService.syncAll(
                  (dirUrl) async => [],
                  feedState.mediaBaseUrl ?? '',
                  feedState.imageHeaders,
                  allFiles,
                );
              } else {
                cacheService.clearAll();
              }
              setState(() {});
            },
          ),
        ),
        // 同步进度条
        if (isEnabled &&
            cacheService.syncStatus == SyncStatus.syncing &&
            cacheService.totalToSync > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value:
                        cacheService.syncedCount / cacheService.totalToSync,
                    minHeight: 3,
                    color: cs.primary,
                    backgroundColor: cs.primary.withOpacity(0.15),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${cacheService.syncedCount} / ${cacheService.totalToSync}',
                  style: textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }
}


/// 同步间隔设置项（独立于缓存开关）
class _SyncIntervalTile extends StatefulWidget {
  const _SyncIntervalTile();

  @override
  State<_SyncIntervalTile> createState() => _SyncIntervalTileState();
}

class _SyncIntervalTileState extends State<_SyncIntervalTile> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appBloc = context.read<AppBloc>();
    final currentInterval = appBloc.state.settings?.cacheSyncInterval ?? 60;
    final intervalLabel = currentInterval < 60
        ? '$currentInterval秒'
        : '${(currentInterval / 60).round()}分钟';

    return ListTile(
      leading: Icon(Icons.timer_outlined, color: cs.onSurfaceVariant),
      title: const Text('同步间隔'),
      subtitle: Text(intervalLabel),
      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
      onTap: () => _showIntervalPicker(context, currentInterval),
    );
  }

  void _showIntervalPicker(BuildContext context, int current) {
    final cs = Theme.of(context).colorScheme;
    final intervalOptions = [30, 60, 120, 180, 300];
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
            Text('同步间隔', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...intervalOptions.map((s) {
              final label = s < 60 ? '${s}秒' : '${(s / 60).round()}分钟';
              return ListTile(
                leading: Icon(Icons.timer_outlined, color: current == s ? cs.primary : null),
                title: Text(label),
                trailing: current == s ? Icon(Icons.check_rounded, color: cs.primary) : null,
                onTap: () {
                  final settings = context.read<AppBloc>().state.settings;
                  if (settings != null) {
                    context.read<AppBloc>().add(AppSettingsUpdatedEvent(
                      settings.copyWith(cacheSyncInterval: s),
                    ));
                  }
                  context.read<CacheService>().setSyncInterval(s);
                  Navigator.pop(ctx);
                  setState(() {});
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 原始数据上传设置项
class _RawDataTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final isEnabled = state.settings?.rawDataEnabled ?? false;
        return SwitchListTile(
          secondary: Icon(Icons.raw_on_rounded, color: cs.onSurfaceVariant),
          title: const Text('原始数据'),
          subtitle: const Text('上传不加密副本到 raw/ 目录'),
          value: isEnabled,
          onChanged: (value) {
            final settings = state.settings;
            if (settings == null) return;
            context.read<AppBloc>().add(AppSettingsUpdatedEvent(
              settings.copyWith(rawDataEnabled: value),
            ));
            final webDavService = context.read<AuthBloc>().webDavService;
            webDavService?.setRawDataEnabled(value);
          },
        );
      },
    );
  }
}

/// 通用设置项
class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.onSurfaceVariant),
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: Icon(Icons.chevron_right_rounded,
          size: 20, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

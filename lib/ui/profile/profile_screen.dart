import 'dart:io';
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../functionality/feed/feed_bloc.dart';
import '../../functionality/home/app_bloc.dart';
import '../../functionality/auth/auth_bloc.dart';
import '../../services/sync_service.dart';
import '../../models/settings.dart' show ThemeMode;
import '../../services/log_service.dart';
import '../../services/encryption_service.dart';
import '../log/log_viewer_screen.dart';
import '../auth/login_screen.dart';

/// 个人中心页面（按 guide.skill 第一节：本地/云端/同步/快照 四大分区）
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    final sync = context.read<SyncService>();
    sync.onSyncStateChanged = () {
      if (mounted) setState(() {});
    };
  }

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
                  // 个人信息
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: GestureDetector(
                        onTap: () =>
                            _editProfile(context, appState, cs, textTheme),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: cs.primaryContainer,
                              child: appState.settings?.avatarPath != null &&
                                      appState.settings!.avatarPath.isNotEmpty
                                  ? ClipOval(
                                      child: Image.file(
                                        File(appState.settings!.avatarPath),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                            Icons.person_rounded,
                                            size: 44,
                                            color: cs.onPrimaryContainer),
                                      ),
                                    )
                                  : Icon(Icons.person_rounded,
                                      size: 44, color: cs.onPrimaryContainer),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              appState.settings?.nickname ?? '媒体管理',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('点击编辑个人资料',
                                style: textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 数据管理分区（按 guide.skill）
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: Text('数据管理',
                          style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant)),
                    ),
                  ),
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
                            _LocalDataTile(),
                            Divider(
                                height: 1,
                                indent: 56,
                                color: cs.outlineVariant.withOpacity(0.2)),
                            _CloudDataTile(),
                            Divider(
                                height: 1,
                                indent: 56,
                                color: cs.outlineVariant.withOpacity(0.2)),
                            _SyncTile(),
                            Divider(
                                height: 1,
                                indent: 56,
                                color: cs.outlineVariant.withOpacity(0.2)),
                            _SnapshotTile(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // 通用设置区
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
                                    builder: (_) => const LogViewerScreen(),
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
                                final logService = context.read<LogService>();
                                final text = logService.export();
                                Clipboard.setData(ClipboardData(text: text));
                                ScaffoldMessenger.of(context).showSnackBar(
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
                            _ThemeTile(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // 危险操作
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
                              onTap: () => _confirmClearCloud(context),
                            ),
                            Divider(
                                height: 1,
                                indent: 56,
                                color: cs.outlineVariant.withOpacity(0.2)),
                            _SettingTile(
                              icon: Icons.logout_rounded,
                              label: '退出登录',
                              onTap: () => _confirmLogout(context),
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
  void _editProfile(BuildContext context, AppState appState, ColorScheme cs,
      TextTheme textTheme) {
    final nicknameController =
        TextEditingController(text: appState.settings?.nickname ?? '媒体管理');
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final settings = appState.settings;
                        if (settings == null) return;
                        final nickname = nicknameController.text.trim().isEmpty
                            ? '媒体管理'
                            : nicknameController.text.trim();
                        String? avatarFileName;
                        if (avatarPath.isNotEmpty &&
                            avatarPath != settings.avatarPath) {
                          // avatarFileName 将通过 SyncService 上传
                        }
                        final syncService = context.read<SyncService>();
                        if (syncService.hasCloudConnection) {
                          await syncService.saveUserProfile(
                            nickname: nickname,
                            localAvatarPath: avatarPath,
                          );
                        }
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

  void _confirmClearCloud(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.warning_rounded, size: 48, color: cs.error),
        title: const Text('清除云端数据'),
        content: const Text('确定要删除 WebDAV 服务器上所有 APP 数据吗？\n\n'
            '包括：\n'
            '• 所有动态（data.json）\n'
            '• 所有媒体文件（图片/视频）\n'
            '• 原始数据副本\n\n'
            '此操作不可恢复！'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final syncService = context.read<SyncService>();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('正在清除数据...'),
                behavior: SnackBarBehavior.floating,
              ));
              await syncService.clearCloudData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('云端数据已清除'),
                  behavior: SnackBarBehavior.floating,
                ));
                context.read<FeedBloc>().add(const FeedLoadEvent());
              }
            },
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(const AuthLogoutEvent());
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

/// 本地数据管理
class _LocalDataTile extends StatefulWidget {
  @override
  State<_LocalDataTile> createState() => _LocalDataTileState();
}

class _LocalDataTileState extends State<_LocalDataTile> {
  String _sizeText = '';

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  Future<void> _loadSize() async {
    final sync = context.read<SyncService>();
    final size = await sync.getLocalDataSize();
    if (mounted) {
      setState(() {
        _sizeText = _formatSize(size);
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sync = context.read<SyncService>();
    return ListTile(
      leading: Icon(Icons.folder_rounded, color: cs.onSurfaceVariant),
      title: const Text('本地数据'),
      subtitle: Text('${sync.localMediaFiles.length} 个文件 · $_sizeText'),
      trailing: Icon(Icons.chevron_right_rounded,
          size: 20, color: cs.onSurfaceVariant),
      onTap: () => _showLocalDataInfo(context, sync),
    );
  }

  void _showLocalDataInfo(BuildContext context, SyncService sync) {
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
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('本地数据管理',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('本地数据信息'),
              subtitle: Text('${sync.localMediaFiles.length} 个文件 · $_sizeText'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: Theme.of(ctx).colorScheme.error),
              title: Text('清除本地数据',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              subtitle: const Text('删除所有本地存储（不影响云端）'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('确认清除'),
                    content: const Text('确定清除所有本地数据吗？\n清除后需要重新同步。'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('取消')),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(c).colorScheme.error),
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('清除'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await sync.clearAll();
                  if (mounted) _loadSize();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('本地数据已清除'),
                          behavior: SnackBarBehavior.floating),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 云端数据管理
class _CloudDataTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final hasCloud = authState.config != null;
        return ListTile(
          leading: Icon(
              hasCloud ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: cs.onSurfaceVariant),
          title: const Text('云端数据'),
          subtitle: Text(hasCloud ? authState.config!.rootUrl : '未配置（本地模式）'),
          trailing: Icon(Icons.chevron_right_rounded,
              size: 20, color: cs.onSurfaceVariant),
          // ★ 点击未配置 → 直接弹登录页，让用户配置 WebDAV
          //   点击已配置 → 显示云端管理信息（地址、路径、登出）
          onTap: () {
            if (!hasCloud) {
              // 未配置 WebDAV：直接跳转登录页（fromProfile=true）
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LoginScreen(fromProfile: true)),
              );
              return;
            }
            // 已配置：弹出云端管理面板
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
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('云端数据管理',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('服务器地址'),
                      subtitle: Text(authState.config?.rootUrl ?? '未连接'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.folder_open_rounded),
                      title: const Text('存储路径'),
                      subtitle: Text(authState.config?.rootPath ?? '-'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.dns_rounded),
                      title: const Text('账号'),
                      subtitle: Text(authState.config?.username ?? '-'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.swap_horiz_rounded,
                          color: Theme.of(ctx).colorScheme.error),
                      title: Text('切换/重新登录',
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error)),
                      subtitle: const Text('登出后可以配置新的 WebDAV 服务器'),
                      onTap: () {
                        Navigator.pop(ctx);
                        // 登出 → 跳到登录页
                        context
                            .read<AuthBloc>()
                            .add(const AuthLogoutEvent());
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const LoginScreen(fromProfile: true)),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 数据同步设置
class _SyncTile extends StatefulWidget {
  @override
  State<_SyncTile> createState() => _SyncTileState();
}

class _SyncTileState extends State<_SyncTile> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sync = context.read<SyncService>();
    final appBloc = context.read<AppBloc>();
    final enabled = sync.enabled;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        String subtitle = '关闭';
        if (enabled) {
          switch (sync.syncStatus) {
            case SyncStatus.syncing:
              subtitle = '同步中 ${sync.syncedCount}/${sync.totalToSync}';
              break;
            case SyncStatus.success:
              subtitle = '已同步';
              break;
            case SyncStatus.failed:
              subtitle = '同步出错';
              break;
            case SyncStatus.idle:
              subtitle = '已开启';
              break;
          }
        } else if (authState.status == AuthStatus.unauthenticated) {
          subtitle = '请先配置 WebDAV';
        }

        return ListTile(
          leading: Icon(
            enabled ? Icons.cloud_sync_rounded : Icons.cloud_off_outlined,
            color: cs.onSurfaceVariant,
          ),
          title: const Text('数据同步'),
          subtitle: Text(subtitle),
          trailing: Switch(
            value: enabled,
            onChanged: (value) {
              // 未连接 WebDAV：提示去配置云端数据，不强制跳登录
              if (authState.status != AuthStatus.authenticated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请先在「云端数据」中配置 WebDAV 服务器'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              // 已连接：直接切换同步
              final settings = appBloc.state.settings;
              if (settings == null) return;
              appBloc.add(AppSettingsUpdatedEvent(
                  settings.copyWith(syncEnabled: value)));
              sync.setEnabled(value);
              if (value) {
                sync.init();
                context.read<FeedBloc>().performManualSync(
                      nickname: settings.nickname,
                      avatarPath: settings.avatarPath,
                    );
              }
              setState(() {});
            },
          ),
        );
      },
    );
  }

  /// 跳转到 WebDAV 登录页（保留当前页面，用户可返回）
  ///
  /// 传入 fromProfile: true，登录成功后会清除整个调用栈，跳到 HomeScreen。
  void _navigateToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen(fromProfile: true)),
    );
  }
}

/// 数据快照管理（思源笔记风格）
class _SnapshotTile extends StatefulWidget {
  @override
  State<_SnapshotTile> createState() => _SnapshotTileState();
}

class _SnapshotTileState extends State<_SnapshotTile> {
  Future<List<SnapshotInfo>>? _future;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.history_rounded, color: cs.onSurfaceVariant),
      title: const Text('数据快照'),
      subtitle: const Text('自动/手动快照 · 恢复前请确认'),
      trailing: Icon(Icons.chevron_right_rounded,
          size: 20, color: cs.onSurfaceVariant),
      onTap: _showSnapshots,
    );
  }

  void _showSnapshots() {
    final sync = context.read<SyncService>();
    _future = sync.listSnapshots();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scroll) {
          return StatefulBuilder(
            builder: (ctx, setSheet) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('数据快照',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        onPressed: () async {
                          final data =
                              await context.read<SyncService>().loadLocalData();
                          if (data != null && context.mounted) {
                            await sync.createSnapshot(data);
                            setSheet(() {
                              _future = sync.listSnapshots();
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text('已创建快照'),
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          }
                        },
                        icon: const Icon(Icons.add_rounded),
                        tooltip: '手动创建快照',
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: FutureBuilder<List<SnapshotInfo>>(
                      future: _future,
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final list = snap.data!;
                        if (list.isEmpty) {
                          return const Center(child: Text('暂无快照'));
                        }
                        return ListView.separated(
                          controller: scroll,
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final s = list[i];
                            return ListTile(
                              leading: const Icon(Icons.bookmark_rounded),
                              title: Text(s.displayTitle),
                              subtitle: Text('${s.postCount} 条动态'),
                              trailing: TextButton(
                                onPressed: () =>
                                    _confirmRestore(context, sync, s),
                                child: const Text('恢复'),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmRestore(
      BuildContext context, SyncService sync, SnapshotInfo s) async {
    Navigator.pop(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('恢复快照'),
        content: Text('确定恢复到 ${s.displayTitle} 的快照吗？\n当前数据将被覆盖。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final data = await sync.restoreSnapshot(s.path);
      if (data != null && context.mounted) {
        context.read<FeedBloc>().add(const FeedLoadEvent());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已恢复到 ${s.displayTitle}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
          title: const Text('主题模式'),
          subtitle: Text(modeLabel),
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

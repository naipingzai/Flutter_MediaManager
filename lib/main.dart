import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'functionality/auth/auth_bloc.dart';
import 'functionality/home/app_bloc.dart';
import 'functionality/feed/feed_bloc.dart';
import 'models/settings.dart' as models;
import 'services/log_service.dart';
import 'services/sync_service.dart';
import 'services/webdav_service.dart';
import 'utils/media_utils.dart';
import 'ui/home/home_screen.dart';
import 'ui/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const FlutterMediaManager());
}

class FlutterMediaManager extends StatefulWidget {
  const FlutterMediaManager({super.key});

  @override
  State<FlutterMediaManager> createState() => _FlutterMediaManagerState();
}

class _FlutterMediaManagerState extends State<FlutterMediaManager> {
  // ★ Bug 修复：之前 BlocBuilder 重建时会反复调用 syncService.init()、
  //   startBackgroundSync()、feedBloc.setWebDavService() 等副作用，
  //   导致数据管理切换逻辑混乱、后台定时器被反复启动。
  //   用 _initialized 标记控制只执行一次；_currentStatus 记录上次认证状态
  //   用于在退出登录时重置标记。
  bool _initialized = false;
  AuthStatus? _lastStatus;

  /// ★ 关键修复：初始化所有基础服务（无论是否有 WebDAV）
  ///
  /// 之前条件 `webDavService != null` 导致本地模式（无 WebDAV）时
  /// MediaUtils.syncService / feedBloc._syncService 永远为 null，
  /// 本地发布文件不保存、查看时图片空白。
  /// 现在分为两步：
  /// 1. 基础服务注入（SyncService、LogService、MediaUtils）— 无条件执行
  /// 2. WebDAV 相关注入（加密、后台同步）— 仅在有 WebDAV 时执行
  void _initializeServices(
    BuildContext context,
    WebDavService? webDavService, // ★ 允许 null（本地模式）
    AppState appState,
  ) {
    final syncService = context.read<SyncService>();
    final logService = context.read<LogService>();
    final appBloc = context.read<AppBloc>();
    final feedBloc = context.read<FeedBloc>();

    // ── 第 1 步：基础服务注入（本地发布必须的） ──
    syncService.setLogService(logService);
    MediaUtils.syncService = syncService;
    feedBloc.setSyncService(syncService);
    feedBloc.setLogService(logService);

    // 认证错误回调（401/403 自动登出）
    feedBloc.setOnAuthError(() {
      try {
        context.read<AuthBloc>().add(const AuthLogoutEvent());
      } catch (_) {}
    });

    // 启动本地媒体扫描（无论同步开关，都先扫描本地数据）
    syncService.init();

    // ── 第 2 步：WebDAV 注入到 SyncService（唯一桥梁） ──
    //   SyncService 会自动从 WebDavService 提取 encryption
    syncService.setWebDavService(webDavService);

    // AppBloc 也通过 SyncService 获取云端信息
    appBloc.setSyncService(syncService);

    final settings = appState.settings;
    final syncEnabled = settings?.syncEnabled ?? true;
    final syncInterval = settings?.syncInterval ?? 60;
    syncService.setEnabled(syncEnabled);
    syncService.setSyncInterval(syncInterval);

    // 后台同步（仅在有云端连接时启动）
    if (syncService.hasCloudConnection && syncEnabled) {
      syncService.startBackgroundSync(() async {
        final data = await syncService.loadLocalData();
        if (data == null) return <String>[];
        final files = <String>[];
        for (final post in data.posts) {
          files.addAll(post.mediaFiles);
          if (post.videoFile != null) files.add(post.videoFile!);
          if (post.videoThumbnail != null) {
            files.add(post.videoThumbnail!);
          }
        }
        return files;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        ChangeNotifierProvider<LogService>(
          create: (_) => LogService(),
        ),
        BlocProvider<AuthBloc>(
          create: (context) {
            final auth = AuthBloc();
            auth.webDavLogger = context.read<LogService>();
            auth.add(const AuthCheckEvent());
            return auth;
          },
        ),
        BlocProvider<AppBloc>(
          create: (context) {
            final appBloc = AppBloc();
            appBloc.logService = context.read<LogService>();
            appBloc.add(const AppInitializeEvent());
            return appBloc;
          },
        ),
        Provider<SyncService>(
          create: (_) => SyncService(),
        ),
        BlocProvider<FeedBloc>(
          create: (context) => FeedBloc(),
        ),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          return BlocBuilder<AppBloc, AppState>(
            builder: (context, appState) {
              final themeMode = appState.settings?.themeMode;

              final webDavService = context.read<AuthBloc>().webDavService;
              final logService = context.read<LogService>();
              final syncService = context.read<SyncService>();

              // ★ Bug 修复：之前这里每次 BlocBuilder 重建都会重复调用
              //   syncService.init()、startBackgroundSync()、setWebDavService() 等，
              //   导致数据管理切换逻辑混乱。
              //   现在只在 _lastStatus 从「未登录」变成「已登录」时调用一次
              //   _initializeServices()，并在退出登录后重置标记。
              final isLoggedIn = authState.status == AuthStatus.authenticated ||
                  authState.status == AuthStatus.local;
              if (isLoggedIn && !_initialized) {
                _initialized = true;
                _lastStatus = authState.status;
                // ★ 修复：不能在 build 期间直接调用 _initializeServices，
                //   因为它内部调用 LogService.log() 会触发 notifyListeners()，
                //   导致 "setState() or markNeedsBuild() called during build" 异常。
                //   用 addPostFrameCallback 延迟到 build 完成后执行。
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _initializeServices(context, webDavService, appState);
                });
              } else if (!isLoggedIn && _initialized) {
                _initialized = false;
                _lastStatus = authState.status;
                // 退出登录后停止后台同步
                try {
                  syncService.stopBackgroundTimer();
                } catch (_) {}
              } else {
                // _lastStatus 发生变化（例如 authenticated → local）时重新初始化
                if (_initialized && _lastStatus != authState.status) {
                  _lastStatus = authState.status;
                  if (webDavService != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _initializeServices(context, webDavService, appState);
                    });
                  }
                }
              }

              return DynamicColorBuilder(
                builder: (lightDynamic, darkDynamic) {
                  return MaterialApp(
                    // 使用 key 让 Navigator 在 authState.status 变化时重建，
                    // 从而彻底清理 Navigator 栈中残留的 LoginScreen / ProfileScreen
                    key: ValueKey('app-${authState.status}'),
                    title: '媒体管理',
                    debugShowCheckedModeBanner: false,
                    theme: _buildLightTheme(lightDynamic),
                    darkTheme: _buildDarkTheme(darkDynamic),
                    themeMode: _getThemeMode(themeMode),
                    home: _buildHome(authState),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHome(AuthState authState) {
    switch (authState.status) {
      case AuthStatus.initial:
      case AuthStatus.checking:
        return const _SplashScreen();
      // 本地为先：未连接 WebDAV 也能正常进入 HomeScreen。
      //   WebDAV 仅是数据同步模块，不决定主页面。
      case AuthStatus.authenticated:
      case AuthStatus.local:
      case AuthStatus.unauthenticated:
      case AuthStatus.loggingIn:
      case AuthStatus.error:
        return const HomeScreen();
    }
  }

  static ThemeMode _getThemeMode(dynamic mode) {
    if (mode == null) return ThemeMode.system;
    if (mode is models.ThemeMode) {
      switch (mode) {
        case models.ThemeMode.light:
          return ThemeMode.light;
        case models.ThemeMode.dark:
          return ThemeMode.dark;
        case models.ThemeMode.system:
          return ThemeMode.system;
      }
    }
    return ThemeMode.system;
  }

  static ThemeData _buildLightTheme(ColorScheme? lightDynamic) {
    final colorScheme = lightDynamic ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B6B),
          brightness: Brightness.light,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.4)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface);
          }
          return TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: colorScheme.surface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withOpacity(0.3),
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData _buildDarkTheme(ColorScheme? darkDynamic) {
    final colorScheme = darkDynamic ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B6B),
          brightness: Brightness.dark,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface);
          }
          return TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: colorScheme.surface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withOpacity(0.3),
        thickness: 1,
        space: 1,
      ),
    );
  }
}

/// 启动画面
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 64, color: cs.primary),
            const SizedBox(height: 24),
            Text(
              '媒体管理',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

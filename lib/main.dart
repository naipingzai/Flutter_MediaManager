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
import 'services/cache_service.dart';
import 'utils/media_utils.dart';
import 'ui/home/home_screen.dart';
import 'ui/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const LifeApp());
}

class LifeApp extends StatelessWidget {
  const LifeApp({super.key});

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
        Provider<CacheService>(
          create: (_) => CacheService(),
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

              // 始终初始化缓存服务（本地模式也需要）
              final cacheService = context.read<CacheService>();
              cacheService.setLogService(logService);
              MediaUtils.cacheService = cacheService;
              final cacheEnabled = appState.settings?.cacheEnabled ?? true;
              cacheService.setEnabled(cacheEnabled);
              if (cacheEnabled) cacheService.init();

              final feedBloc = context.read<FeedBloc>();
              feedBloc.setCacheService(cacheService);
              feedBloc.setLogService(logService);

              // WebDAV 连接（仅认证后）
              if ((authState.status == AuthStatus.authenticated ||
                   authState.status == AuthStatus.local) &&
                  webDavService != null) {
                final appBloc = context.read<AppBloc>();
                appBloc.setWebDavService(webDavService);
                cacheService.setEncryption(webDavService.encryption);
                final syncInterval = appState.settings?.cacheSyncInterval ?? 60;
                cacheService.setSyncInterval(syncInterval);
                webDavService.setRawDataEnabled(appState.settings?.rawDataEnabled ?? false);

                feedBloc.setWebDavService(webDavService);
                feedBloc.setOnAuthError(() {
                  context.read<AuthBloc>().add(const AuthLogoutEvent());
                });

                if (cacheEnabled) {
                  cacheService.startBackgroundSync(() async {
                    final data = await cacheService.loadLocalData();
                    if (data == null) return [];
                    final files = <String>[];
                    for (final post in data.posts) {
                      files.addAll(post.mediaFiles);
                      if (post.videoFile != null) files.add(post.videoFile!);
                      if (post.videoThumbnail != null) files.add(post.videoThumbnail!);
                    }
                    return files;
                  });
                }
              }

              return DynamicColorBuilder(
                builder: (lightDynamic, darkDynamic) {
                  return MaterialApp(
                    title: '生活动态',
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
      case AuthStatus.authenticated:
      case AuthStatus.local:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
      case AuthStatus.loggingIn:
        return const LoginScreen();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              '生活动态',
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

import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/settings.dart';
import '../../services/local_settings_service.dart';
import '../../services/log_service.dart';
import '../../services/webdav_service.dart';

part 'app_event.dart';
part 'app_state.dart';

/// 应用级 Bloc，管理全局状态（主题、设置、导航等）
class AppBloc extends Bloc<AppEvent, AppState> {
  final LocalSettingsService _settingsService = LocalSettingsService();
  LogService? _logService;
  set logService(LogService value) => _logService = value;

  WebDavService? _webDavService;

  void setWebDavService(WebDavService? service) {
    if (_webDavService != service) {
      _webDavService = service;
      // Re-load profile from WebDAV when service changes (e.g. re-login)
      if (service != null && state.settings != null) {
        add(const AppInitializeEvent());
      }
    }
  }

  AppBloc() : super(const AppState()) {
    on<AppInitializeEvent>(_onInitialize);
    on<AppThemeChangedEvent>(_onThemeChanged);
    on<AppSettingsUpdatedEvent>(_onSettingsUpdated);
    on<AppNavigationChangedEvent>(_onNavigationChanged);
  }

  Future<void> _onInitialize(
    AppInitializeEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(status: AppStatus.initializing));
    _logService?.info('应用初始化开始', source: 'App');
    try {
      var settings = await _settingsService.getSettings();

      // 尝试从 WebDAV 加载用户资料
      if (_webDavService != null) {
        try {
          final profile = await _webDavService!.loadUserProfile();
          if (profile != null) {
            settings = AppSettings(
              themeMode: settings.themeMode,
              gridColumns: settings.gridColumns,
              albumGridColumns: settings.albumGridColumns,
              thumbnailQuality: settings.thumbnailQuality,
              language: settings.language,
              dynamicColor: settings.dynamicColor,
              lastScanPath: settings.lastScanPath,
              cacheEnabled: settings.cacheEnabled,
              nickname: profile['nickname'] as String? ?? settings.nickname,
              avatarPath: settings.avatarPath,
            );
            // 保存到本地
            await _settingsService.saveSettings(settings);
            _logService?.success('WebDAV 用户资料已加载', source: 'App');

            // 下载头像到本地
            final avatarFileName = profile['avatarFileName'] as String?;
            if (avatarFileName != null && avatarFileName.isNotEmpty) {
              try {
                final avatarUrl = '${_webDavService!.config.rootUrl}/$avatarFileName';
                final dio = Dio();
                final response = await dio.get<List<int>>(
                  avatarUrl,
                  options: Options(
                    responseType: ResponseType.bytes,
                    headers: _webDavService!.imageHeaders,
                  ),
                );
                if (response.data != null) {
                  final appDir = await getApplicationDocumentsDirectory();
                  final localAvatarPath = '${appDir.path}/$avatarFileName';
                  await File(localAvatarPath).writeAsBytes(
                    Uint8List.fromList(response.data!),
                  );
                  final updatedSettings = AppSettings(
                    themeMode: settings.themeMode,
                    gridColumns: settings.gridColumns,
                    albumGridColumns: settings.albumGridColumns,
                    thumbnailQuality: settings.thumbnailQuality,
                    language: settings.language,
                    dynamicColor: settings.dynamicColor,
                    lastScanPath: settings.lastScanPath,
                    cacheEnabled: settings.cacheEnabled,
                    nickname: settings.nickname,
                    avatarPath: localAvatarPath,
                  );
                  await _settingsService.saveSettings(updatedSettings);
                  emit(state.copyWith(settings: updatedSettings));
                  _logService?.success('头像已下载到本地', detail: localAvatarPath, source: 'App');
                }
              } catch (e) {
                _logService?.warn('头像下载失败', detail: e.toString(), source: 'App');
              }
            }
          }
        } catch (e) {
          _logService?.warn('加载 WebDAV 用户资料失败', detail: e.toString(), source: 'App');
        }
      }

      _logService?.success('应用初始化完成', source: 'App');
      emit(state.copyWith(
        status: AppStatus.ready,
        settings: settings,
      ));
    } catch (e) {
      _logService?.error('应用初始化失败', detail: e.toString(), source: 'App');
      emit(state.copyWith(
        status: AppStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onThemeChanged(
    AppThemeChangedEvent event,
    Emitter<AppState> emit,
  ) async {
    if (state.settings == null) return;
    final newSettings = AppSettings(
      themeMode: event.themeMode,
      gridColumns: state.settings!.gridColumns,
      albumGridColumns: state.settings!.albumGridColumns,
      thumbnailQuality: state.settings!.thumbnailQuality,
      language: state.settings!.language,
      dynamicColor: state.settings!.dynamicColor,
      lastScanPath: state.settings!.lastScanPath,
      cacheEnabled: state.settings!.cacheEnabled,
      nickname: state.settings!.nickname,
      avatarPath: state.settings!.avatarPath,
    );
    try {
      await _settingsService.saveSettings(newSettings);
      _logService?.info('主题设置已保存',
          detail: event.themeMode.toString(), source: 'App');
      emit(state.copyWith(settings: newSettings));
    } catch (e) {
      _logService?.error('保存主题设置失败', detail: e.toString(), source: 'App');
    }
  }

  Future<void> _onSettingsUpdated(
    AppSettingsUpdatedEvent event,
    Emitter<AppState> emit,
  ) async {
    try {
      await _settingsService.saveSettings(event.settings);
      _logService?.info('设置已更新', source: 'App');
      emit(state.copyWith(settings: event.settings));
    } catch (e) {
      _logService?.error('保存设置失败', detail: e.toString(), source: 'App');
    }
  }

  void _onNavigationChanged(
    AppNavigationChangedEvent event,
    Emitter<AppState> emit,
  ) {
    _logService?.info('导航切换',
        detail: 'tabIndex=${event.tabIndex}', source: 'App');
    emit(state.copyWith(currentTabIndex: event.tabIndex));
  }
}

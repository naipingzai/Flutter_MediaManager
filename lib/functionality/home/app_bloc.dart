import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/settings.dart';
import '../../services/local_settings_service.dart';
import '../../services/log_service.dart';
import '../../services/sync_service.dart';

part 'app_event.dart';
part 'app_state.dart';

/// 应用级 Bloc，管理全局状态（主题、设置、导航等）
/// ★ 重构：只依赖 SyncService，不直接依赖 WebDavService
class AppBloc extends Bloc<AppEvent, AppState> {
  final LocalSettingsService _settingsService = LocalSettingsService();
  LogService? _logService;
  set logService(LogService value) => _logService = value;

  SyncService? _syncService;

  void setSyncService(SyncService service) {
    _syncService = service;
    // 重新加载用户资料
    if (state.settings != null) {
      add(const AppInitializeEvent());
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

      // 尝试从 SyncService 加载用户资料（SyncService 代理 WebDAV）
      if (_syncService != null && _syncService!.hasCloudConnection) {
        try {
          final profile = await _syncService!.loadUserProfile();
          if (profile != null) {
            settings = settings.copyWith(
              nickname: profile['nickname'] as String? ?? settings.nickname,
            );
            await _settingsService.saveSettings(settings);
            _logService?.success('云端用户资料已加载', source: 'App');

            // 下载头像到本地
            final avatarFileName = profile['avatarFileName'] as String?;
            if (avatarFileName != null && avatarFileName.isNotEmpty) {
              try {
                final avatarUrl = _syncService!.getMediaUrl(avatarFileName);
                if (avatarUrl != null) {
                  final dio = Dio();
                  final response = await dio.get<List<int>>(
                    avatarUrl,
                    options: Options(
                      responseType: ResponseType.bytes,
                      headers: _syncService!.imageHeaders,
                    ),
                  );
                  if (response.data != null) {
                    final appDir = await getApplicationDocumentsDirectory();
                    final localAvatarPath = '${appDir.path}/$avatarFileName';
                    await File(localAvatarPath).writeAsBytes(
                      Uint8List.fromList(response.data!),
                    );
                    final updatedSettings = settings.copyWith(
                      avatarPath: localAvatarPath,
                    );
                    await _settingsService.saveSettings(updatedSettings);
                    emit(state.copyWith(settings: updatedSettings));
                    _logService?.success('头像已下载到本地',
                        detail: localAvatarPath, source: 'App');
                  }
                }
              } catch (e) {
                _logService?.warn('头像下载失败', detail: e.toString(), source: 'App');
              }
            }
          }
        } catch (e) {
          _logService?.warn('加载云端用户资料失败', detail: e.toString(), source: 'App');
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
    final newSettings = state.settings!.copyWith(themeMode: event.themeMode);
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

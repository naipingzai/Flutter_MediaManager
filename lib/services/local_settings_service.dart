import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';
import 'log_service.dart';

/// 本地设置服务（使用 SharedPreferences，不依赖原生 FFI）
class LocalSettingsService {
  static const _keyThemeMode = 'theme_mode';
  static const _keyGridColumns = 'grid_columns';
  static const _keyAlbumGridColumns = 'album_grid_columns';
  static const _keyThumbnailQuality = 'thumbnail_quality';
  static const _keyLanguage = 'language';
  static const _keyDynamicColor = 'dynamic_color';
  static const _keyLastScanPath = 'last_scan_path';
  static const _keySyncEnabled = 'sync_enabled';
  static const _keySyncInterval = 'sync_interval';
  static const _keyRawDataEnabled = 'raw_data_enabled';
  static const _keyNickname = 'user_nickname';
  static const _keyAvatarPath = 'user_avatar_path';

  LogService? _logService;
  set logService(LogService value) => _logService = value;

  Future<AppSettings> getSettings() async {
    _logService?.info('读取本地设置', source: 'Settings');
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_keyThemeMode) ?? 0;
      final settings = AppSettings(
        themeMode: ThemeMode.values[themeIndex.clamp(0, 2)],
        gridColumns: prefs.getInt(_keyGridColumns) ?? 3,
        albumGridColumns: prefs.getInt(_keyAlbumGridColumns) ?? 2,
        thumbnailQuality: prefs.getInt(_keyThumbnailQuality) ?? 85,
        language: prefs.getString(_keyLanguage) ?? 'system',
        dynamicColor: prefs.getInt(_keyDynamicColor) ?? 1,
        lastScanPath: prefs.getString(_keyLastScanPath) ?? '',
        syncEnabled: prefs.getBool(_keySyncEnabled) ?? false,
        syncInterval: prefs.getInt(_keySyncInterval) ?? 60,
        rawDataEnabled: prefs.getBool(_keyRawDataEnabled) ?? false,
        nickname: prefs.getString(_keyNickname) ?? '媒体管理',
        avatarPath: prefs.getString(_keyAvatarPath) ?? '',
      );
      _logService?.success('本地设置读取完成', source: 'Settings');
      return settings;
    } catch (e) {
      _logService?.error('读取本地设置失败', detail: e.toString(), source: 'Settings');
      rethrow;
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    _logService?.info('保存本地设置', source: 'Settings');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyThemeMode, settings.themeMode.index);
      await prefs.setInt(_keyGridColumns, settings.gridColumns);
      await prefs.setInt(_keyAlbumGridColumns, settings.albumGridColumns);
      await prefs.setInt(_keyThumbnailQuality, settings.thumbnailQuality);
      await prefs.setString(_keyLanguage, settings.language);
      await prefs.setInt(_keyDynamicColor, settings.dynamicColor);
      await prefs.setString(_keyLastScanPath, settings.lastScanPath);
      await prefs.setBool(_keySyncEnabled, settings.syncEnabled);
      await prefs.setInt(_keySyncInterval, settings.syncInterval);
      await prefs.setBool(_keyRawDataEnabled, settings.rawDataEnabled);
      await prefs.setString(_keyNickname, settings.nickname);
      await prefs.setString(_keyAvatarPath, settings.avatarPath);
      _logService?.success('本地设置保存完成', source: 'Settings');
    } catch (e) {
      _logService?.error('保存本地设置失败', detail: e.toString(), source: 'Settings');
      rethrow;
    }
  }
}

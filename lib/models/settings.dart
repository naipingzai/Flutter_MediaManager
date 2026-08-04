/// 主题模式（对应 Flutter ThemeMode）
enum ThemeMode { system, light, dark }

/// 应用设置
///
/// 按 guide.skill 规范：APP 中不存在"缓存"概念
/// 改用：syncEnabled（数据同步开关）/ syncInterval（同步间隔）
class AppSettings {
  final ThemeMode themeMode;
  final int gridColumns;
  final int albumGridColumns;
  final int thumbnailQuality;
  final String language;
  final int dynamicColor;
  final String lastScanPath;
  final bool syncEnabled;
  final int syncInterval;
  final bool rawDataEnabled;
  final String nickname;
  final String avatarPath;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.gridColumns = 3,
    this.albumGridColumns = 2,
    this.thumbnailQuality = 85,
    this.language = 'system',
    this.dynamicColor = 1,
    this.lastScanPath = '',
    this.syncEnabled = false,
    this.syncInterval = 60,
    this.rawDataEnabled = false,
    this.nickname = '生活记录者',
    this.avatarPath = '',
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? gridColumns,
    int? albumGridColumns,
    int? thumbnailQuality,
    String? language,
    int? dynamicColor,
    String? lastScanPath,
    bool? syncEnabled,
    int? syncInterval,
    bool? rawDataEnabled,
    String? nickname,
    String? avatarPath,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      gridColumns: gridColumns ?? this.gridColumns,
      albumGridColumns: albumGridColumns ?? this.albumGridColumns,
      thumbnailQuality: thumbnailQuality ?? this.thumbnailQuality,
      language: language ?? this.language,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      lastScanPath: lastScanPath ?? this.lastScanPath,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      syncInterval: syncInterval ?? this.syncInterval,
      rawDataEnabled: rawDataEnabled ?? this.rawDataEnabled,
      nickname: nickname ?? this.nickname,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}

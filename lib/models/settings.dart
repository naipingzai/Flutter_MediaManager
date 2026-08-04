/// 主题模式（对应 Flutter ThemeMode）
enum ThemeMode { system, light, dark }

/// 应用设置
class AppSettings {
  final ThemeMode themeMode;
  final int gridColumns;
  final int albumGridColumns;
  final int thumbnailQuality;
  final String language;
  final int dynamicColor;
  final String lastScanPath;
  final bool cacheEnabled; // 是否开启本地缓存
  final int cacheSyncInterval; // 缓存同步间隔（秒）
  final bool rawDataEnabled; // 是否上传原始数据（不加密副本）
  final String nickname; // 用户昵称
  final String avatarPath; // 用户头像本地路径

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.gridColumns = 3,
    this.albumGridColumns = 2,
    this.thumbnailQuality = 85,
    this.language = 'system',
    this.dynamicColor = 1,
    this.lastScanPath = '',
    this.cacheEnabled = false,
    this.cacheSyncInterval = 60,
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
    bool? cacheEnabled,
    int? cacheSyncInterval,
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
      cacheEnabled: cacheEnabled ?? this.cacheEnabled,
      cacheSyncInterval: cacheSyncInterval ?? this.cacheSyncInterval,
      rawDataEnabled: rawDataEnabled ?? this.rawDataEnabled,
      nickname: nickname ?? this.nickname,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}

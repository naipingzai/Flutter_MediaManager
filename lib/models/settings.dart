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
    this.nickname = '生活记录者',
    this.avatarPath = '',
  });
}

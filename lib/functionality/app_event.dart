part of 'app_bloc.dart';

/// AppBloc 事件基类
abstract class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => [];
}

/// 应用初始化事件
class AppInitializeEvent extends AppEvent {
  const AppInitializeEvent();
}

/// 主题切换事件
class AppThemeChangedEvent extends AppEvent {
  final ThemeMode themeMode;

  const AppThemeChangedEvent(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

/// 设置更新事件
class AppSettingsUpdatedEvent extends AppEvent {
  final AppSettings settings;

  const AppSettingsUpdatedEvent(this.settings);

  @override
  List<Object?> get props => [settings];
}

/// 导航切换事件
class AppNavigationChangedEvent extends AppEvent {
  final int tabIndex;

  const AppNavigationChangedEvent(this.tabIndex);

  @override
  List<Object?> get props => [tabIndex];
}

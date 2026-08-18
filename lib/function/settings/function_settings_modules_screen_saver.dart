import 'package:flutter_media_view/function/filters/function_filters.dart';
import 'package:flutter_media_view/function/settings/function_settings_defaults.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';

mixin ScreenSaverSettings on SettingsAccess {
  bool get screenSaverFillScreen => getBool(SettingKeys.screenSaverFillScreenKey) ?? SettingsDefaults.slideshowFillScreen;

  set screenSaverFillScreen(bool newValue) => set(SettingKeys.screenSaverFillScreenKey, newValue);

  bool get screenSaverAnimatedZoomEffect => getBool(SettingKeys.screenSaverAnimatedZoomEffectKey) ?? SettingsDefaults.slideshowAnimatedZoomEffect;

  set screenSaverAnimatedZoomEffect(bool newValue) => set(SettingKeys.screenSaverAnimatedZoomEffectKey, newValue);

  ViewerTransition get screenSaverTransition => getEnumOrDefault(SettingKeys.screenSaverTransitionKey, SettingsDefaults.slideshowTransition, ViewerTransition.values);

  set screenSaverTransition(ViewerTransition newValue) => set(SettingKeys.screenSaverTransitionKey, newValue.name);

  SlideshowVideoPlayback get screenSaverVideoPlayback => getEnumOrDefault(SettingKeys.screenSaverVideoPlaybackKey, SettingsDefaults.slideshowVideoPlayback, SlideshowVideoPlayback.values);

  set screenSaverVideoPlayback(SlideshowVideoPlayback newValue) => set(SettingKeys.screenSaverVideoPlaybackKey, newValue.name);

  int get screenSaverInterval => getInt(SettingKeys.screenSaverIntervalKey) ?? SettingsDefaults.slideshowInterval;

  set screenSaverInterval(int newValue) => set(SettingKeys.screenSaverIntervalKey, newValue);

  Set<CollectionFilter> get screenSaverCollectionFilters => (getStringList(SettingKeys.screenSaverCollectionFiltersKey) ?? []).map(CollectionFilter.fromJson).nonNulls.toSet();

  set screenSaverCollectionFilters(Set<CollectionFilter> newValue) => set(SettingKeys.screenSaverCollectionFiltersKey, newValue.map((filter) => filter.toJsonString()).toList());
}

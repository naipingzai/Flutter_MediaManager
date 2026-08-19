import 'package:fmv/function/device/function_device.dart';
import 'package:fmv/function/settings/defaults.dart';
import 'package:fmv_model/flutter_media_view_model.dart';

mixin DisplaySettings on SettingsAccess {
  DisplayRefreshRateMode get displayRefreshRateMode => getEnumOrDefault(SettingKeys.displayRefreshRateModeKey, SettingsDefaults.displayRefreshRateMode, DisplayRefreshRateMode.values);

  set displayRefreshRateMode(DisplayRefreshRateMode newValue) => set(SettingKeys.displayRefreshRateModeKey, newValue.name);

  FmvThemeBrightness get themeBrightness => getEnumOrDefault(SettingKeys.themeBrightnessKey, SettingsDefaults.themeBrightness, FmvThemeBrightness.values);

  set themeBrightness(FmvThemeBrightness newValue) => set(SettingKeys.themeBrightnessKey, newValue.name);

  FmvThemeColorMode get themeColorMode => getEnumOrDefault(SettingKeys.themeColorModeKey, SettingsDefaults.themeColorMode, FmvThemeColorMode.values);

  set themeColorMode(FmvThemeColorMode newValue) => set(SettingKeys.themeColorModeKey, newValue.name);

  bool get enableDynamicColor => getBool(SettingKeys.enableDynamicColorKey) ?? SettingsDefaults.enableDynamicColor;

  set enableDynamicColor(bool newValue) => set(SettingKeys.enableDynamicColorKey, newValue);

  bool get enableBlurEffect => getBool(SettingKeys.enableBlurEffectKey) ?? SettingsDefaults.enableBlurEffect;

  set enableBlurEffect(bool newValue) => set(SettingKeys.enableBlurEffectKey, newValue);

  MaxBrightness get maxBrightness => getEnumOrDefault(SettingKeys.maxBrightnessKey, SettingsDefaults.maxBrightness, MaxBrightness.values);

  set maxBrightness(MaxBrightness newValue) => set(SettingKeys.maxBrightnessKey, newValue.name);

  bool get forceTvLayout => getBool(SettingKeys.forceTvLayoutKey) ?? SettingsDefaults.forceTvLayout;

  set forceTvLayout(bool newValue) => set(SettingKeys.forceTvLayoutKey, newValue);

  bool get useTvLayout => device.isTelevision || forceTvLayout;

  bool get isReadOnly => useTvLayout;
}

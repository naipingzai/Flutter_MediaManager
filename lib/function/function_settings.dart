import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter_media_view/app_flavor.dart';
import 'package:flutter_media_view/function/function_device.dart';
import 'package:flutter_media_view/function/function_dynamic_albums.dart';
import 'package:flutter_media_view/function/function_filters_favourite.dart';
import 'package:flutter_media_view/function/function_filters_mime.dart';
import 'package:flutter_media_view/function/function_grouping_common.dart';
import 'package:flutter_media_view/function/function_settings_defaults.dart';
import 'package:flutter_media_view/function/function_settings_enums_accessibility_animations.dart';
import 'package:flutter_media_view/function/function_settings_modules_app.dart';
import 'package:flutter_media_view/function/function_settings_modules_collection.dart';
import 'package:flutter_media_view/function/function_settings_modules_debug.dart';
import 'package:flutter_media_view/function/function_settings_modules_display.dart';
import 'package:flutter_media_view/function/function_settings_modules_filter_grids.dart';
import 'package:flutter_media_view/function/function_settings_modules_history.dart';
import 'package:flutter_media_view/function/function_settings_modules_info.dart';
import 'package:flutter_media_view/function/function_settings_modules_map.dart';
import 'package:flutter_media_view/function/function_settings_modules_navigation.dart';
import 'package:flutter_media_view/function/function_settings_modules_privacy.dart';
import 'package:flutter_media_view/function/function_settings_modules_screen_saver.dart';
import 'package:flutter_media_view/function/function_settings_modules_slideshow.dart';
import 'package:flutter_media_view/function/function_settings_modules_viewer.dart';
import 'package:flutter_media_view/function/function_settings_modules_widget.dart';
import 'package:flutter_media_view/function/function_bursts.dart';
import 'package:flutter_media_view/function/function_accessibility_service.dart';
import 'package:flutter_media_view/function/function_common_services.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_search_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_filter_grids_albums_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_filter_grids_countries_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_filter_grids_places_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_filter_grids_tags_page.dart';
import 'package:flutter_media_view_map/flutter_media_view_map.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter_media_view_utils/flutter_media_view_utils.dart';
import 'package:flutter_media_view_video/flutter_media_view_video.dart';
import 'package:collection/collection.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

final Settings settings = Settings._private();

class Settings
    with
        ChangeNotifier,
        SettingsAccess,
        AppSettings,
        CollectionSettings,
        DebugSettings,
        DisplaySettings,
        FilterGridsSettings,
        HistorySettings,
        InfoSettings,
        MapSettings,
        NavigationSettings,
        PrivacySettings,
        ScreenSaverSettings,
        SlideshowSettings,
        SubtitlesSettings,
        VideoSettings,
        ViewerSettings,
        WidgetSettings {
  final Set<StreamSubscription> _subscriptions = {};
  final EventChannel _platformSettingsChangeChannel = const OptionalEventChannel('deckers.thibault/aves/settings_change');
  final StreamController<SettingsChangedEvent> _updateStreamController = StreamController.broadcast();
  final StreamController<SettingsChangedEvent> _updateTileExtentStreamController = StreamController.broadcast();

  @override
  Stream<SettingsChangedEvent> get updateStream => _updateStreamController.stream;

  Stream<SettingsChangedEvent> get updateTileExtentStream => _updateTileExtentStreamController.stream;

  @override
  bool get initialized => store.initialized;

  @override
  SettingsStore get store => settingsStore;

  Settings._private() {
    if (kFlutterMemoryAllocationsEnabled) ChangeNotifier.maybeDispatchObjectCreation(this);
  }

  Future<void> init({
    required bool monitorPlatformSettings,
    required bool shouldSanitize,
  }) async {
    await store.init();
    resetResolvedLocale();
    _unregister();
    _register(monitorPlatformSettings);
    initHistorySettings();
    if (shouldSanitize) {
      await sanitize();
    }
  }

  void _unregister() {
    albumGrouping.removeListener(saveAlbumGroups);
    tagGrouping.removeListener(saveTagGroups);
    _subscriptions
      ..forEach((sub) => sub.cancel())
      ..clear();
  }

  void _register(bool monitorPlatformSettings) {
    albumGrouping.addListener(saveAlbumGroups);
    tagGrouping.addListener(saveTagGroups);
    _subscriptions.add(
      dynamicAlbums.eventBus.on<DynamicAlbumChangedEvent>().listen((e) {
        final changes = e.changes;
        updateBookmarkedDynamicAlbums(changes);
        updatePinnedDynamicAlbums(changes);
      }),
    );
    _subscriptions.add(albumGrouping.eventBus.on<GroupUriChangedEvent>().listen(_onGroupingChange));
    _subscriptions.add(tagGrouping.eventBus.on<GroupUriChangedEvent>().listen(_onGroupingChange));
    if (monitorPlatformSettings) {
      _subscriptions.add(_platformSettingsChangeChannel.receiveBroadcastStream().listen((event) => _onPlatformSettingsChanged(event as Map?)));
    }
  }

  void _onGroupingChange(GroupUriChangedEvent event) {
    final oldGroupUri = event.oldGroupUri;
    final newGroupUri = event.newGroupUri;
    updateBookmarkedGroup(oldGroupUri, newGroupUri);
    updatePinnedGroup(oldGroupUri, newGroupUri);
  }

  Future<void> reload() => store.reload();

  Future<void> reset({required bool includeInternalKeys}) async {
    if (includeInternalKeys) {
      await store.clear();
    } else {
      await Future.forEach<String>(store.getKeys().whereNot(SettingKeys.isInternalKey), store.remove);
    }
  }

  Future<void> setContextualDefaults(AppFlavor flavor) async {
    // performance
    final performanceClass = await deviceService.getMediaPerformanceClass();
    enableBlurEffect = performanceClass >= 31;

    if (!Platform.isAndroid) return;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final manufacturer = androidInfo.manufacturer.toLowerCase();
    final pattern = BurstPatterns.byManufacturer[manufacturer];
    collectionBurstPatterns = pattern != null ? [pattern] : [];

    // availability
    if (flavor.hasMapStyleDefault) {
      final defaultMapStyle = mobileServices.defaultMapStyle;
      if (defaultMapStyle != null && mobileServices.mapStyles.contains(defaultMapStyle)) {
        mapStyle = defaultMapStyle;
      } else {
        final styles = EntryMapStyles.baseStyles;
        mapStyle = styles[Random().nextInt(styles.length)];
      }
    }

    if (settings.useTvLayout) {
      applyTvSettings();
    }
  }

  void applyTvSettings() {
    themeBrightness = AvesThemeBrightness.dark;
    maxBrightness = MaxBrightness.never;
    mustBackTwiceToExit = false;
    // address `TV-BU` / `TV-BY` requirements from https://developer.android.com/docs/quality-guidelines/tv-app-quality
    keepScreenOn = KeepScreenOn.videoPlayback;
    drawerTypeBookmarks = [
      null,
      MimeFilter.video,
      FavouriteFilter.instance,
    ];
    drawerPageBookmarks = [
      AlbumListPage.routeName,
      CountryListPage.routeName,
      PlaceListPage.routeName,
      TagListPage.routeName,
      SearchPage.routeName,
    ];
    bottomNavigationActions = [];
    showOverlayOnOpening = false;
    showOverlayMinimap = false;
    showOverlayZoomLevel = false;
    showOverlayThumbnailPreview = false;
    viewerGestureSideTapNext = false;
    viewerUseCutout = true;
    videoBackgroundMode = VideoBackgroundMode.disabled;
    videoControlActions = [];
    videoGestureDoubleTapTogglePlay = false;
    videoGestureSideDoubleTapSeek = false;
    enableBin = false;
    showPinchGestureAlternatives = true;
    resetShowTitleQuery();
  }

  Future<void> sanitize() async {
    if (timeToTakeAction == AccessibilityTimeout.system && !await AccessibilityService.hasRecommendedTimeouts()) {
      set(SettingKeys.timeToTakeActionKey, null);
    }
    if (viewerUseCutout != SettingsDefaults.viewerUseCutout && !await windowService.isCutoutAware()) {
      set(SettingKeys.viewerUseCutoutKey, null);
    }
    if (videoBackgroundMode == VideoBackgroundMode.pip && !device.supportPictureInPicture) {
      set(SettingKeys.videoBackgroundModeKey, null);
    }
    collectionBurstPatterns = collectionBurstPatterns.where(BurstPatterns.options.contains).toList();

    // emulator
    if (!device.isPhysicalDevice) {
      set(SettingKeys.videoHardwareAccelerationKey, VideoHardwareAcceleration.disabled);
    }
  }

  // tag editor

  bool get tagEditorCurrentFilterSectionExpanded => getBool(SettingKeys.tagEditorCurrentFilterSectionExpandedKey) ?? SettingsDefaults.tagEditorCurrentFilterSectionExpanded;

  set tagEditorCurrentFilterSectionExpanded(bool newValue) => set(SettingKeys.tagEditorCurrentFilterSectionExpandedKey, newValue);

  String? get tagEditorExpandedSection => getString(SettingKeys.tagEditorExpandedSectionKey);

  set tagEditorExpandedSection(String? newValue) => set(SettingKeys.tagEditorExpandedSectionKey, newValue);

  // converter

  String get convertMimeType => getString(SettingKeys.convertMimeTypeKey) ?? SettingsDefaults.convertMimeType;

  set convertMimeType(String newValue) => set(SettingKeys.convertMimeTypeKey, newValue);

  int get convertQuality => getInt(SettingKeys.convertQualityKey) ?? SettingsDefaults.convertQuality;

  set convertQuality(int newValue) => set(SettingKeys.convertQualityKey, newValue);

  bool get convertWriteMetadata => getBool(SettingKeys.convertWriteMetadataKey) ?? SettingsDefaults.convertWriteMetadata;

  set convertWriteMetadata(bool newValue) => set(SettingKeys.convertWriteMetadataKey, newValue);

  // bin

  bool get enableBin => getBool(SettingKeys.enableBinKey) ?? SettingsDefaults.enableBin;

  set enableBin(bool newValue) => set(SettingKeys.enableBinKey, newValue);

  // accessibility

  bool get showPinchGestureAlternatives => getBool(SettingKeys.showPinchGestureAlternativesKey) ?? SettingsDefaults.showPinchGestureAlternatives;

  set showPinchGestureAlternatives(bool newValue) => set(SettingKeys.showPinchGestureAlternativesKey, newValue);

  AccessibilityAnimations get accessibilityAnimations => getEnumOrDefault(SettingKeys.accessibilityAnimationsKey, SettingsDefaults.accessibilityAnimations, AccessibilityAnimations.values);

  bool get animate => accessibilityAnimations.animate;

  set accessibilityAnimations(AccessibilityAnimations newValue) => set(SettingKeys.accessibilityAnimationsKey, newValue.name);

  AccessibilityTimeout get timeToTakeAction => getEnumOrDefault(SettingKeys.timeToTakeActionKey, SettingsDefaults.timeToTakeAction, AccessibilityTimeout.values);

  set timeToTakeAction(AccessibilityTimeout newValue) => set(SettingKeys.timeToTakeActionKey, newValue.name);

  // platform settings

  void _onPlatformSettingsChanged(Map? fields) {
    fields?.forEach((key, value) {
      switch (key) {
        case SettingKeys.platformAccelerometerRotationKey:
          if (value is num) {
            isRotationLocked = value == 0;
          }
        case SettingKeys.platformTransitionAnimationScaleKey:
          if (value is num) {
            areAnimationsRemoved = value == 0;
          }
        case SettingKeys.platformLongPressTimeoutMillisKey:
          if (value is num) {
            longPressTimeoutMillis = value.toInt();
          }
      }
    });
  }

  bool get isRotationLocked => getBool(SettingKeys.platformAccelerometerRotationKey) ?? SettingsDefaults.isRotationLocked;

  set isRotationLocked(bool newValue) => set(SettingKeys.platformAccelerometerRotationKey, newValue);

  bool get areAnimationsRemoved => getBool(SettingKeys.platformTransitionAnimationScaleKey) ?? SettingsDefaults.areAnimationsRemoved;

  set areAnimationsRemoved(bool newValue) => set(SettingKeys.platformTransitionAnimationScaleKey, newValue);

  Duration get longPressTimeout => Duration(milliseconds: getInt(SettingKeys.platformLongPressTimeoutMillisKey) ?? kLongPressTimeout.inMilliseconds);

  set longPressTimeoutMillis(int newValue) => set(SettingKeys.platformLongPressTimeoutMillisKey, newValue);

  // import/export

  Map<String, Object?> export() => Map.fromEntries(
    store.getKeys().whereNot(SettingKeys.isInternalKey).map((k) => MapEntry(k, store.get(k))),
  );

  Future<void> import(Object jsonMap) async {
    if (jsonMap is! Map) {
      debugPrint('failed to import settings for jsonMap=$jsonMap');
      return;
    }

    // clear to restore defaults
    await reset(includeInternalKeys: false);

    // apply user modifications
    jsonMap.cast<String, Object?>().forEach((key, newValue) {
      final oldValue = store.get(key);

      if (newValue == null) {
        store.remove(key);
      } else if (key.startsWith(SettingKeys.tileExtentPrefixKey)) {
        if (newValue is double) {
          store.setDouble(key, newValue);
        } else {
          debugPrint('failed to import key=$key, value=$newValue is not a double');
        }
      } else if (key.startsWith(SettingKeys.tileLayoutPrefixKey)) {
        if (newValue is String) {
          store.setString(key, newValue);
        } else {
          debugPrint('failed to import key=$key, value=$newValue is not a string');
        }
      } else if (key.startsWith(SettingKeys.showTitleQueryPrefixKey)) {
        if (newValue is bool) {
          store.setBool(key, newValue);
        } else {
          debugPrint('failed to import key=$key, value=$newValue is not a bool');
        }
      } else {
        switch (key) {
          case SettingKeys.convertQualityKey:
          case SettingKeys.screenSaverIntervalKey:
          case SettingKeys.slideshowIntervalKey:
            if (newValue is int) {
              store.setInt(key, newValue);
            } else {
              debugPrint('failed to import key=$key, value=$newValue is not an int');
            }
          case SettingKeys.subtitleFontSizeKey:
          case SettingKeys.infoMapZoomKey:
            if (newValue is double) {
              store.setDouble(key, newValue);
            } else {
              debugPrint('failed to import key=$key, value=$newValue is not a double');
            }
          case SettingKeys.isInstalledAppAccessAllowedKey:
          case SettingKeys.isErrorReportingAllowedKey:
          case SettingKeys.forceWesternArabicNumeralsKey:
          case SettingKeys.enableDynamicColorKey:
          case SettingKeys.enableBlurEffectKey:
          case SettingKeys.mustBackTwiceToExitKey:
          case SettingKeys.confirmCreateVaultKey:
          case SettingKeys.confirmDeleteForeverKey:
          case SettingKeys.confirmMoveToBinKey:
          case SettingKeys.confirmMoveUndatedItemsKey:
          case SettingKeys.confirmAfterMoveToBinKey:
          case SettingKeys.setMetadataDateBeforeFileOpKey:
          case SettingKeys.collectionSortReverseKey:
          case SettingKeys.showThumbnailFavouriteKey:
          case SettingKeys.showThumbnailHdrKey:
          case SettingKeys.showThumbnailMotionPhotoKey:
          case SettingKeys.showThumbnailRatingKey:
          case SettingKeys.showThumbnailRawKey:
          case SettingKeys.showThumbnailSlowMotionVideoKey:
          case SettingKeys.showThumbnailVideoDurationKey:
          case SettingKeys.albumSortReverseKey:
          case SettingKeys.countrySortReverseKey:
          case SettingKeys.stateSortReverseKey:
          case SettingKeys.placeSortReverseKey:
          case SettingKeys.tagSortReverseKey:
          case SettingKeys.showOverlayOnOpeningKey:
          case SettingKeys.showOverlayMinimapKey:
          case SettingKeys.showOverlayZoomLevelKey:
          case SettingKeys.showOverlayInfoKey:
          case SettingKeys.showOverlayDescriptionKey:
          case SettingKeys.showOverlayRatingTagsKey:
          case SettingKeys.showOverlayShootingDetailsKey:
          case SettingKeys.showOverlayThumbnailPreviewKey:
          case SettingKeys.viewerGestureSideTapNextKey:
          case SettingKeys.viewerUseCutoutKey:
          case SettingKeys.enableMotionPhotoAutoPlayKey:
          case SettingKeys.videoGestureDoubleTapTogglePlayKey:
          case SettingKeys.videoGestureSideDoubleTapSeekKey:
          case SettingKeys.videoGestureVerticalDragBrightnessVolumeKey:
          case SettingKeys.subtitleShowOutlineKey:
          case SettingKeys.tagEditorCurrentFilterSectionExpandedKey:
          case SettingKeys.convertWriteMetadataKey:
          case SettingKeys.mapShowItemTracksKey:
          case SettingKeys.saveSearchHistoryKey:
          case SettingKeys.showPinchGestureAlternativesKey:
          case SettingKeys.screenSaverFillScreenKey:
          case SettingKeys.screenSaverAnimatedZoomEffectKey:
          case SettingKeys.slideshowRepeatKey:
          case SettingKeys.slideshowShuffleKey:
          case SettingKeys.slideshowFillScreenKey:
          case SettingKeys.slideshowAnimatedZoomEffectKey:
            if (newValue is bool) {
              store.setBool(key, newValue);
            } else {
              debugPrint('failed to import key=$key, value=$newValue is not a bool');
            }
          case SettingKeys.autoExportPathKey:
          case SettingKeys.localeKey:
          case SettingKeys.calendarKey:
          case SettingKeys.displayRefreshRateModeKey:
          case SettingKeys.themeBrightnessKey:
          case SettingKeys.themeColorModeKey:
          case SettingKeys.maxBrightnessKey:
          case SettingKeys.keepScreenOnKey:
          case SettingKeys.homePageKey:
          case SettingKeys.homeCustomExplorerPathKey:
          case SettingKeys.collectionGroupFactorKey:
          case SettingKeys.collectionSortFactorKey:
          case SettingKeys.thumbnailLocationIconKey:
          case SettingKeys.thumbnailTagIconKey:
          case SettingKeys.albumSectionFactorKey:
          case SettingKeys.albumSortFactorKey:
          case SettingKeys.countrySortFactorKey:
          case SettingKeys.stateSortFactorKey:
          case SettingKeys.placeSortFactorKey:
          case SettingKeys.tagSortFactorKey:
          case SettingKeys.albumGroupsKey:
          case SettingKeys.tagGroupsKey:
          case SettingKeys.imageBackgroundKey:
          case SettingKeys.videoAutoPlayModeKey:
          case SettingKeys.videoBackgroundModeKey:
          case SettingKeys.videoHardwareAccelerationKey:
          case SettingKeys.videoLoopModeKey:
          case SettingKeys.videoResumptionModeKey:
          case SettingKeys.subtitleTextAlignmentKey:
          case SettingKeys.subtitleTextPositionKey:
          case SettingKeys.subtitleTextColorKey:
          case SettingKeys.subtitleBackgroundColorKey:
          case SettingKeys.tagEditorExpandedSectionKey:
          case SettingKeys.convertMimeTypeKey:
          case SettingKeys.mapStyleKey:
          case SettingKeys.mapDefaultCenterKey:
          case SettingKeys.coordinateFormatKey:
          case SettingKeys.unitSystemKey:
          case SettingKeys.accessibilityAnimationsKey:
          case SettingKeys.timeToTakeActionKey:
          case SettingKeys.screenSaverTransitionKey:
          case SettingKeys.screenSaverVideoPlaybackKey:
          case SettingKeys.slideshowTransitionKey:
          case SettingKeys.slideshowVideoPlaybackKey:
            if (newValue is String) {
              store.setString(key, newValue);
            } else {
              debugPrint('failed to import key=$key, value=$newValue is not a string');
            }
          case SettingKeys.customMapStylesKey:
          case SettingKeys.homeCustomCollectionKey:
          case SettingKeys.drawerTypeBookmarksKey:
          case SettingKeys.drawerAlbumBookmarksKey:
          case SettingKeys.drawerPageBookmarksKey:
          case SettingKeys.bottomNavigationActionsKey:
          case SettingKeys.collectionBurstPatternsKey:
          case SettingKeys.pinnedFiltersKey:
          case SettingKeys.hiddenFiltersKey:
          case SettingKeys.deactivatedHiddenFiltersKey:
          case SettingKeys.collectionBrowsingQuickActionsKey:
          case SettingKeys.collectionSelectionQuickActionsKey:
          case SettingKeys.viewerQuickActionsKey:
          case SettingKeys.videoControlActionsKey:
          case SettingKeys.screenSaverCollectionFiltersKey:
            if (newValue is List) {
              store.setStringList(key, newValue.cast<String>());
            } else {
              debugPrint('failed to import key=$key, value=$newValue is not a list');
            }
        }
      }
      if (hasValueChanged(oldValue, newValue)) {
        notifyKeyChange(key, oldValue, newValue);
      }
    });
    await sanitize();
    notifyListeners();
  }

  @override
  void notifyKeyChange(String key, Object? oldValue, Object? newValue) {
    _updateStreamController.add(SettingsChangedEvent(key, oldValue, newValue));
    if (key.startsWith(SettingKeys.tileExtentPrefixKey)) {
      _updateTileExtentStreamController.add(SettingsChangedEvent(key, oldValue, newValue));
    }
    if (!SettingKeys.isInternalKey(key)) {
      final recent = recentSettingKeys..insert(0, key);
      recentSettingKeys = recent.toSet().toList();
    }
  }
}

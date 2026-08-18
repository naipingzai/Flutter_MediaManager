import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_media_view/function/model/availability.dart';
import 'package:flutter_media_view/function/db/db.dart';
import 'package:flutter_media_view/function/db/db_sqflite.dart';
import 'package:flutter_media_view/function/settings/store_shared_pref.dart';
import 'package:flutter_media_view/function/settings/app_profile_service.dart';
import 'package:flutter_media_view/function/settings/app_service.dart';
import 'package:flutter_media_view/function/services/device_service.dart';
import 'package:flutter_media_view/function/services/geocoding_service.dart';
import 'package:flutter_media_view/function/media/embedded_data_service.dart';
import 'package:flutter_media_view/function/media/import_service.dart';
import 'package:flutter_media_view/function/media/internal_dir_media_fetch_service.dart';
import 'package:flutter_media_view/function/media/internal_dir_media_store_service.dart';
import 'package:flutter_media_view/function/media/media_edit_service.dart';
import 'package:flutter_media_view/function/media/media_fetch_service.dart';
import 'package:flutter_media_view/function/media/media_session_service.dart';
import 'package:flutter_media_view/function/media/media_store_service.dart';
import 'package:flutter_media_view/function/metadata/dart_metadata_fetch_service.dart';
import 'package:flutter_media_view/function/metadata/metadata_edit_service.dart';
import 'package:flutter_media_view/function/metadata/metadata_fetch_service.dart';
import 'package:flutter_media_view/function/services/security_service.dart';
import 'package:flutter_media_view/function/services/storage_service.dart';
import 'package:flutter_media_view/function/services/window_service.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter_media_view_report/flutter_media_view_report.dart';
import 'package:flutter_media_view_report_platform/flutter_media_view_report_platform.dart';
import 'package:flutter_media_view_services/flutter_media_view_services.dart';
import 'package:flutter_media_view_services_platform/flutter_media_view_services_platform.dart';
import 'package:flutter_media_view_video/flutter_media_view_video.dart';
import 'package:flutter_media_view_video_mpv/flutter_media_view_video_mpv.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;

final getIt = GetIt.instance;

// fixed implementation is easier for test driver setup
final SettingsStore settingsStore = SharedPrefSettingsStore();

final p.Context pContext = getIt<p.Context>();
final FmvAvailability availability = getIt<FmvAvailability>();
final LocalMediaDb localMediaDb = getIt<LocalMediaDb>();
final FmvVideoControllerFactory videoControllerFactory = getIt<FmvVideoControllerFactory>();
final FmvVideoMetadataFetcher videoMetadataFetcher = getIt<FmvVideoMetadataFetcher>();

final AppService appService = getIt<AppService>();
final AppProfileService appProfileService = getIt<AppProfileService>();
final DeviceService deviceService = getIt<DeviceService>();
final EmbeddedDataService embeddedDataService = getIt<EmbeddedDataService>();
final GeocodingService geocodingService = getIt<GeocodingService>();
final MediaEditService mediaEditService = getIt<MediaEditService>();
final MediaFetchService mediaFetchService = getIt<MediaFetchService>();
final MediaSessionService mediaSessionService = getIt<MediaSessionService>();
final MediaStoreService mediaStoreService = getIt<MediaStoreService>();
final ImportService importService = getIt<ImportService>();
final MetadataEditService metadataEditService = getIt<MetadataEditService>();
final MetadataFetchService metadataFetchService = getIt<MetadataFetchService>();
final MobileServices mobileServices = getIt<MobileServices>();
final ReportService reportService = getIt<ReportService>();
final SecurityService securityService = getIt<SecurityService>();
final StorageService storageService = getIt<StorageService>();
final WindowService windowService = getIt<WindowService>();

void initPlatformServices() {
  // 桌面平台（Linux/Windows/macOS）无 sqflite 平台实现，改用 FFI（SQLite over dart:ffi）
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  getIt.registerLazySingleton<p.Context>(p.Context.new);
  getIt.registerLazySingleton<FmvAvailability>(LiveFmvAvailability.new);
  getIt.registerLazySingleton<LocalMediaDb>(SqfliteLocalMediaDb.new);
  getIt.registerLazySingleton<FmvVideoControllerFactory>(MpvVideoControllerFactory.new);
  getIt.registerLazySingleton<FmvVideoMetadataFetcher>(MpvVideoMetadataFetcher.new);

  getIt.registerLazySingleton<AppService>(PlatformAppService.new);
  getIt.registerLazySingleton<AppProfileService>(PlatformAppProfileService.new);
  getIt.registerLazySingleton<DeviceService>(PlatformDeviceService.new);
  getIt.registerLazySingleton<EmbeddedDataService>(PlatformEmbeddedDataService.new);
  getIt.registerLazySingleton<GeocodingService>(PlatformGeocodingService.new);
  getIt.registerLazySingleton<MediaEditService>(PlatformMediaEditService.new);
  getIt.registerLazySingleton<MediaFetchService>(InternalDirMediaFetchService.new);
  getIt.registerLazySingleton<MediaSessionService>(PlatformMediaSessionService.new);
  getIt.registerLazySingleton<MediaStoreService>(InternalDirMediaStoreService.new);
  getIt.registerLazySingleton<ImportService>(ImportService.new);
  getIt.registerLazySingleton<MetadataEditService>(PlatformMetadataEditService.new);
  getIt.registerLazySingleton<MetadataFetchService>(DartMetadataFetchService.new);
  getIt.registerLazySingleton<MobileServices>(PlatformMobileServices.new);
  getIt.registerLazySingleton<ReportService>(PlatformReportService.new);
  getIt.registerLazySingleton<SecurityService>(PlatformSecurityService.new);
  getIt.registerLazySingleton<StorageService>(PlatformStorageService.new);
  getIt.registerLazySingleton<WindowService>(PlatformWindowService.new);
}

import 'package:flutter_media_view/function/model/function_availability.dart';
import 'package:flutter_media_view/function/db/function_db.dart';
import 'package:flutter_media_view/function/model/function_dynamic_albums.dart';
import 'package:flutter_media_view/function/grouping/function_grouping_common.dart';
import 'package:flutter_media_view/function/settings/function_settings.dart';
import 'package:flutter_media_view/function/settings/function_app_service.dart';
import 'package:flutter_media_view/function/common/function_common_services.dart';
import 'package:flutter_media_view/function/services/function_device_service.dart';
import 'package:flutter_media_view/function/media/function_media_media_fetch_service.dart';
import 'package:flutter_media_view/function/media/function_media_media_store_service.dart';
import 'package:flutter_media_view/function/metadata/function_metadata_metadata_fetch_service.dart';
import 'package:flutter_media_view/function/services/function_storage_service.dart';
import 'package:flutter_media_view/function/services/function_window_service.dart';
import 'package:flutter_media_view/function/utils/function_android_file_utils.dart';
import 'package:flutter_media_view_report/flutter_media_view_report.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'fake/android_app_service.dart';
import 'fake/availability.dart';
import 'fake/db.dart';
import 'fake/device_service.dart';
import 'fake/media_fetch_service.dart';
import 'fake/media_store_service.dart';
import 'fake/metadata_fetch_service.dart';
import 'fake/report_service.dart';
import 'fake/storage_service.dart';
import 'fake/window_service.dart';

Future<void> setUpAllServices() async {
  // specify Posix style path context for consistent behaviour when running tests on Windows
  getIt.registerLazySingleton<p.Context>(() => p.Context(style: p.Style.posix));
  getIt.registerLazySingleton<AvesAvailability>(FakeAvesAvailability.new);
  getIt.registerLazySingleton<LocalMediaDb>(FakeAvesDb.new);

  getIt.registerLazySingleton<AppService>(FakeAppService.new);
  getIt.registerLazySingleton<DeviceService>(FakeDeviceService.new);
  getIt.registerLazySingleton<MediaFetchService>(FakeMediaFetchService.new);
  getIt.registerLazySingleton<MediaStoreService>(FakeMediaStoreService.new);
  getIt.registerLazySingleton<MetadataFetchService>(FakeMetadataFetchService.new);
  getIt.registerLazySingleton<ReportService>(FakeReportService.new);
  getIt.registerLazySingleton<StorageService>(FakeStorageService.new);
  getIt.registerLazySingleton<WindowService>(FakeWindowService.new);

  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
  await settings.init(monitorPlatformSettings: false, shouldSanitize: false);
  await androidFileUtils.init();

  albumGrouping.init();
  tagGrouping.init();
}

Future<void> setUpServices() async {
  (getIt<MediaStoreService>() as FakeMediaStoreService).reset();

  await settings.reset(includeInternalKeys: true);
  settings.canUseAnalysisService = false;

  albumGrouping.setGroups({});
  tagGrouping.setGroups({});

  await dynamicAlbums.clear();
}

Future<void> tearDownAllServices() async {
  await getIt.reset();
}

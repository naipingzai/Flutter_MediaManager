import 'package:fmv/function/model/availability.dart';
import 'package:fmv/function/db/db.dart';
import 'package:fmv/function/model/dynamic_albums.dart';
import 'package:fmv/function/grouping/common.dart';
import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/function/settings/app_service.dart';
import 'package:fmv/function/common/services.dart';
import 'package:fmv/function/services/device_service.dart';
import 'package:fmv/function/media/media_fetch_service.dart';
import 'package:fmv/function/media/media_store_service.dart';
import 'package:fmv/function/metadata/media_fetch_service.dart';
import 'package:fmv/function/services/storage_service.dart';
import 'package:fmv/function/services/window_service.dart';
import 'package:fmv/function/utils/android_file_utils.dart';
import 'package:fmv_report/flutter_media_view_report.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'fake/android_app_service.dart';
import 'fake/availability.dart';
import 'fake/db.dart';
import 'fake/device_service.dart';
import 'fake/media_fetch_service.dart';
import 'fake/media_store_service.dart';
import 'fake/media_fetch_service.dart';
import 'fake/report_service.dart';
import 'fake/storage_service.dart';
import 'fake/window_service.dart';

Future<void> setUpAllServices() async {
  // specify Posix style path context for consistent behaviour when running tests on Windows
  getIt.registerLazySingleton<p.Context>(() => p.Context(style: p.Style.posix));
  getIt.registerLazySingleton<FmvAvailability>(FakeAvesAvailability.new);
  getIt.registerLazySingleton<LocalMediaDb>(FakeFmvDb.new);

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

import 'package:flutter_media_view/function/settings/function_app_inventory.dart';
import 'package:flutter_media_view/function/settings/function_app_service.dart';
import 'package:flutter/foundation.dart';
import 'package:test/fake.dart';

class FakeAppService extends Fake implements AppService {
  @override
  Future<Set<Package>> getPackages() => SynchronousFuture({});
}

import 'package:flutter_media_view/model/entry/entry.dart';
import 'package:flutter_media_view/services/media/media_fetch_service.dart';
import 'package:collection/collection.dart';
import 'package:test/fake.dart';

class FakeMediaFetchService extends Fake implements MediaFetchService {
  Set<AvesEntry> entries = {};

  @override
  Future<AvesEntry?> getEntry(String uri, String? mimeType, {bool allowUnsized = false}) async {
    return entries.firstWhereOrNull((v) => v.uri == uri);
  }
}

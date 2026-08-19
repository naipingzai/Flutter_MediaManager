import 'package:fmv/function/entry/entry.dart';
import 'package:fmv/function/media/media_fetch_service.dart';
import 'package:collection/collection.dart';
import 'package:test/fake.dart';

class FakeMediaFetchService extends Fake implements MediaFetchService {
  Set<FmvEntry> entries = {};

  @override
  Future<FmvEntry?> getEntry(String uri, String? mimeType, {bool allowUnsized = false}) async {
    return entries.firstWhereOrNull((v) => v.uri == uri);
  }
}

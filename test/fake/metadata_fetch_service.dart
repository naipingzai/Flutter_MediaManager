import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/metadata/catalog.dart';
import 'package:flutter_media_view/function/metadata/fetch_service.dart';
import 'package:flutter/foundation.dart';
import 'package:test/fake.dart';

class FakeMetadataFetchService extends Fake implements MetadataFetchService {
  final Map<FmvEntry, CatalogMetadata> _metaMap = {};

  void setUp(FmvEntry entry, CatalogMetadata metadata) => _metaMap[entry] = metadata;

  @override
  Future<CatalogMetadata?> getCatalogMetadata(FmvEntry entry, {bool background = false}) => SynchronousFuture(_metaMap[entry]);
}

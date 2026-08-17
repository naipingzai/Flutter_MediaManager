import 'package:flutter_media_view/model/entry/entry.dart';
import 'package:flutter_media_view/model/metadata/catalog.dart';
import 'package:flutter_media_view/services/metadata/metadata_fetch_service.dart';
import 'package:flutter/foundation.dart';
import 'package:test/fake.dart';

class FakeMetadataFetchService extends Fake implements MetadataFetchService {
  final Map<AvesEntry, CatalogMetadata> _metaMap = {};

  void setUp(AvesEntry entry, CatalogMetadata metadata) => _metaMap[entry] = metadata;

  @override
  Future<CatalogMetadata?> getCatalogMetadata(AvesEntry entry, {bool background = false}) => SynchronousFuture(_metaMap[entry]);
}

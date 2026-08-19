import 'package:flutter_media_view/function/model/covers.dart';
import 'package:flutter_media_view/function/model/dynamic_albums.dart';
import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/model/favourites.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/metadata/address.dart';
import 'package:flutter_media_view/function/metadata/catalog.dart';
import 'package:flutter_media_view/function/metadata/metadata_trash.dart';
import 'package:flutter_media_view/function/model/function_vaults_details.dart';
import 'package:flutter_media_view/function/viewer/video_playback.dart';

abstract class LocalMediaDb {
  int get nextId;

  Future<String> get path;

  Future<void> init();

  Future<int> dbFileSize();

  Future<void> reset();

  Future<void> removeIds(Set<int> ids, {Set<EntryDataType>? dataTypes});

  // entries

  Future<void> clearEntries();

  Future<Set<FmvEntry>> loadEntries({int? origin, String? directory});

  Future<Set<FmvEntry>> loadEntriesById(Set<int> ids);

  Future<void> insertEntries(Set<FmvEntry> entries);

  Future<void> updateEntry(int id, FmvEntry entry);

  Future<Set<FmvEntry>> searchLiveEntries(String query, {int? limit});

  Future<Set<FmvEntry>> searchLiveDuplicates(int origin, Set<FmvEntry>? entries);

  // date taken

  Future<void> clearDates();

  Future<Map<int?, int?>> loadDates();

  // catalog metadata

  Future<void> clearCatalogMetadata();

  Future<Set<CatalogMetadata>> loadCatalogMetadata();

  Future<Set<CatalogMetadata>> loadCatalogMetadataById(Set<int> ids);

  Future<void> saveCatalogMetadata(Set<CatalogMetadata> metadataEntries);

  Future<void> updateCatalogMetadata(int id, CatalogMetadata? metadata);

  // address

  Future<void> clearAddresses();

  Future<Set<AddressDetails>> loadAddresses();

  Future<Set<AddressDetails>> loadAddressesById(Set<int> ids);

  Future<void> saveAddresses(Set<AddressDetails> addresses);

  Future<void> updateAddress(int id, AddressDetails? address);

  // vaults

  Future<void> clearVaults();

  Future<Set<VaultDetails>> loadAllVaults();

  Future<void> addVaults(Set<VaultDetails> rows);

  Future<void> updateVault(String oldName, VaultDetails row);

  Future<void> removeVaults(Set<VaultDetails> rows);

  // trash

  Future<void> clearTrashDetails();

  Future<Set<TrashDetails>> loadAllTrashDetails();

  Future<void> updateTrash(int id, TrashDetails? details);

  // favourites

  Future<void> clearFavourites();

  Future<Set<FavouriteRow>> loadAllFavourites();

  Future<void> addFavourites(Set<FavouriteRow> rows);

  Future<void> updateFavouriteId(int id, FavouriteRow row);

  Future<void> removeFavourites(Set<FavouriteRow> rows);

  // covers

  Future<void> clearCovers();

  Future<Set<CoverRow>> loadAllCovers();

  Future<void> addCovers(Set<CoverRow> rows);

  Future<void> updateCoverEntryId(int id, CoverRow row);

  Future<void> removeCovers(Set<CollectionFilter> filters);

  // dynamic albums

  Future<int> clearDynamicAlbums();

  Future<Set<DynamicAlbumRow>> loadAllDynamicAlbums();

  Future<void> addDynamicAlbums(Set<DynamicAlbumRow> rows);

  Future<void> removeDynamicAlbums(Set<String> names);

  // video playback

  Future<void> clearVideoPlayback();

  Future<Set<VideoPlaybackRow>> loadAllVideoPlayback();

  Future<VideoPlaybackRow?> loadVideoPlayback(int id);

  Future<void> addVideoPlayback(Set<VideoPlaybackRow> rows);

  Future<void> removeVideoPlayback(Set<int> ids);
}

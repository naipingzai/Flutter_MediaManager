import 'package:flutter_media_view/function/model/dynamic_albums.dart';
import 'package:flutter_media_view/function/filters/container_album_group.dart';
import 'package:flutter_media_view/function/filters/container_dynamic_album.dart';
import 'package:flutter_media_view/function/filters/container_set_or.dart';
import 'package:flutter_media_view/function/filters/covered_stored_album.dart';
import 'package:flutter_media_view/function/grouping/common.dart';
import 'package:flutter_media_view/function/grouping/grouping_convert.dart';
import 'package:test/test.dart';

import '../../common.dart';

void main() {
  const groupName = 'some group name';
  const storedAlbumPath = '/path/to/album/';

  setUpAll(() async {
    await setUpAllServices();
  });

  setUp(() async {
    await setUpServices();
  });

  tearDownAll(() async {
    await tearDownAllServices();
  });

  test('Filter URI round trip', () {
    final storedAlbumFilter = StoredAlbumFilter(storedAlbumPath, 'display name');
    final dynamicAlbumFilter = DynamicAlbumFilter('dynamic name', storedAlbumFilter);
    dynamicAlbums.add(dynamicAlbumFilter);
    final groupUri = albumGrouping.buildGroupUri(null, groupName);
    final albumGroupFilter = AlbumGroupFilter(groupUri, SetOrFilter({storedAlbumFilter, dynamicAlbumFilter}));

    expect(albumGrouping.uriToFilter(GroupingConversion.filterToUri(storedAlbumFilter)), storedAlbumFilter);
    expect(albumGrouping.uriToFilter(GroupingConversion.filterToUri(dynamicAlbumFilter)), dynamicAlbumFilter);
    expect(albumGrouping.uriToFilter(GroupingConversion.filterToUri(albumGroupFilter)), albumGroupFilter);
  });
}

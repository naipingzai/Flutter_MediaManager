import 'package:flutter_media_view/function/model/function_dynamic_albums.dart';
import 'package:flutter_media_view/function/filters/function_filters_container_album_group.dart';
import 'package:flutter_media_view/function/filters/function_filters_container_dynamic_album.dart';
import 'package:flutter_media_view/function/filters/function_filters_container_set_or.dart';
import 'package:flutter_media_view/function/filters/function_filters_covered_stored_album.dart';
import 'package:flutter_media_view/function/grouping/function_grouping_common.dart';
import 'package:flutter_media_view/function/grouping/function_grouping_convert.dart';
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

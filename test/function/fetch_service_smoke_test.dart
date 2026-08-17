import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_media_view/function/function_media_internal_dir_media_fetch_service.dart';
import 'package:flutter_media_view/ui/ui_image_providers_thumbnail_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('InternalDirMediaFetchService 可解码本地 PNG', () async {
    // 用仓库里的真实 png 资产
    final png = File('assets/map_tile_128_osm_hot.png');
    expect(await png.exists(), isTrue, reason: '测试资产应存在');

    final service = InternalDirMediaFetchService();
    final key = ThumbnailProviderKey(
      uri: png.path.startsWith('/') ? 'file://${png.path}' : 'file://${png.absolute.path}',
      pageId: null,
      mimeType: 'image/png',
      extent: 128,
      rotationDegrees: 0,
      isFlipped: false,
      dateModifiedMillis: 0,
    );
    final codec = await service.getThumbnail(
      decoded: false,
      request: key,
    );
    final frame = await codec.getNextFrame();
    print('FETCH_OK ${frame.image.width}x${frame.image.height}');
    expect(frame.image.width, greaterThan(0));
  });
}

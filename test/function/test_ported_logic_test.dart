import 'dart:typed_data';

import 'package:flutter_media_view/function/function_bmp_writer.dart';
import 'package:flutter_media_view/function/function_byte_utils.dart';
import 'package:flutter_media_view/function/function_hash_utils.dart';
import 'package:flutter_media_view/function/function_quicktime_metadata.dart';
import 'package:flutter_media_view/function/function_spherical_video.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvesByteUtils', () {
    test('toHex 输出小写十六进制', () {
      expect([0xde, 0xad, 0xbe, 0xef].toHex(), 'deadbeef');
      expect([0x00].toHex(), '00');
    });

    test('indexOfBytes Boyer-Moore 搜索', () {
      final data = 'hello world, aves here'.codeUnits;
      expect(data.indexOfBytes('aves'.codeUnits), 13);
      expect(data.indexOfBytes('xyz'.codeUnits), -1);
      expect(data.indexOfBytes('o'.codeUnits, 5), 7);
    });

    test('toUtf16BeString 解码 UTF-16BE（含代理对）', () {
      // "Hi" -> 0x0048 0x0069
      expect([0x00, 0x48, 0x00, 0x69].toUtf16BeString(), 'Hi');
      // U+1D11E (𝄞) 代理对 D834 DD1E
      expect([0xD8, 0x34, 0xDD, 0x1E].toUtf16BeString(), '𝄞');
    });
  });

  group('HashUtils', () {
    test('hashBytes 与已知摘要一致', () {
      // 使用 crypto 参考值：md5("") = d41d8cd98f00b204e9800998ecf8427e
      expect(HashUtils.hashBytes(<int>[], 'md5'), 'd41d8cd98f00b204e9800998ecf8427e');
      expect(HashUtils.hashBytes(<int>[], 'sha1'), 'da39a3ee5e6b4b0d3255bfef95601890afd80709');
      expect(HashUtils.hashBytes(<int>[], 'sha256'), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    });

    test('不支持的算法抛出 ArgumentError', () {
      expect(() => HashUtils.hashBytes(<int>[], 'crc32'), throwsArgumentError);
    });
  });

  group('QuickTimeMetadata', () {
    test('ISO 639 语言位域解析', () {
      // 0x55c4 -> "und"
      final language = QuickTimeMetadata.parseLanguage([0x55, 0xc4]);
      expect(language, 'und');
    });

    test('解析 USMT/MTDT 元数据块', () {
      final bytes = _buildMtdtBox();
      final blocks = QuickTimeMetadata.parseUuidUsmt(bytes);
      expect(blocks, isNotEmpty);
      expect(blocks.first.type, anyOf('Title', 'Software', 'Creation Time'));
      expect(blocks.first.language, 'und');
    });
  });

  group('GSpherical', () {
    test('解析 Spherical Video V1 XML', () {
      const xml = '<rdf:SphericalVideo xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" '
          'xmlns:GSpherical="http://ns.google.com/videos/1.0/spherical/">'
          '<GSpherical:Spherical>true</GSpherical:Spherical>'
          '<GSpherical:Stitched>true</GSpherical:Stitched>'
          '<GSpherical:StitchingSoftware>open source</GSpherical:StitchingSoftware>'
          '<GSpherical:ProjectionType>equirectangular</GSpherical:ProjectionType>'
          '<GSpherical:SourceCount>6</GSpherical:SourceCount>'
          '</rdf:SphericalVideo>';
      final describe = GSpherical(xml).describe();
      expect(describe['Spherical'], 'true');
      expect(describe['Stitched'], 'true');
      expect(describe['Stitching Software'], 'open source');
      expect(describe['Projection Type'], 'equirectangular');
      expect(describe['Source Count'], '6');
      expect(describe.containsKey('Stereo Mode'), isFalse);
    });

    test('非法 XML 容错', () {
      expect(GSpherical('not < a valid xml').describe()['Spherical'], 'false');
    });
  });

  group('BmpWriter', () {
    test('BMP 头与文件大小正确', () {
      // 2x2 红绿蓝白
      const width = 2, height = 2;
      final rgba = Uint8List.fromList([
        255, 0, 0, 255, //
        0, 255, 0, 255,
        0, 0, 255, 255,
        255, 255, 255, 255,
      ]);
      final bmp = BmpWriter.writeRGB24(width, height, rgba);
      // 文件头
      expect(bmp[0], 0x42); // 'B'
      expect(bmp[1], 0x4D); // 'M'
      expect(bmp.length, 14 + 40 + 2 * 2 * 3 + 2 * 2); // 行宽 6 字节 + 每行填充 2 字节
      // 像素自下而上：BMP 第一行是源图最后一行 [蓝, 白]
      const pixelStart = 54;
      expect(bmp[pixelStart], 255); // 蓝的 B
      expect(bmp[pixelStart + 1], 0); // 蓝的 G
      expect(bmp[pixelStart + 2], 0); // 蓝的 R
      // 第二个像素为白色（源图右下）
      expect(bmp[pixelStart + 3], 255); // 白的 B
      expect(bmp[pixelStart + 4], 255); // 白的 G
      expect(bmp[pixelStart + 5], 255); // 白的 R
    });
  });
}

// 构造一个最小 MTDT 盒：盒头(size+type) + blockCount(2) + 一个 0x01 编码字符串块
Uint8List _buildMtdtBox() {
  final payload = <int>[
    // block: size=14, type=0x01 (Title), lang=0x55c4 (und), encoding=0x01 (UTF-16BE), "Hi"
    0x00, 0x0E, 0x00, 0x00, 0x00, 0x01, 0x55, 0xc4, 0x00, 0x01, 0x00, 0x48, 0x00, 0x69,
  ];
  final data = <int>[
    ..._be32(4 + 4 + 2 + payload.length), // box size
    ...'MTDT'.codeUnits, // box type
    0x00, 0x01, // block count
    ...payload,
  ];
  return Uint8List.fromList(data);
}

List<int> _be32(int v) => [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

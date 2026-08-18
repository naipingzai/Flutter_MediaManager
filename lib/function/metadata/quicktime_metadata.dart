import 'package:flutter_media_view/function/utils/byte_utils.dart';

/// QuickTime `USMT`/`MTDT` 盒解析器，
/// 移植自 Android `metadata/QuickTimeMetadata.kt`，无平台依赖，可复用于任何目标。
class QuickTimeMetadataBlock {
  final String type;
  final String value;
  final String language;

  const QuickTimeMetadataBlock({
    required this.type,
    required this.value,
    required this.language,
  });
}

class QuickTimeMetadata {
  QuickTimeMetadata._();

  // QuickTime Profile Tags
  // cf https://exiftool.org/TagNames/QuickTime.html#Profile
  static const profUuid = '50524f46-21d2-4fce-bb88-695cfac9c740';

  // QuickTime UserMedia Tags
  // cf https://exiftool.org/TagNames/QuickTime.html#UserMedia
  static const usmtUuid = '55534d54-21d2-4fce-bb88-695cfac9c740';

  static const _metadataBoxId = 'MTDT';

  /// 解析 QuickTime `uuid`/`USMT` 盒数据中的 `MTDT` 元数据块列表。
  static List<QuickTimeMetadataBlock> parseUuidUsmt(List<int> data) {
    final blocks = <QuickTimeMetadataBlock>[];
    final boxHeader = BoxHeader(data);
    if (boxHeader.boxType == _metadataBoxId) {
      blocks.addAll(_parseQuicktimeMtdtBox(boxHeader, data));
    }
    return blocks;
  }

  static List<QuickTimeMetadataBlock> _parseQuicktimeMtdtBox(BoxHeader boxHeader, List<int> data) {
    final blocks = <QuickTimeMetadataBlock>[];
    var bytes = data;
    final blockCount = _beU16(bytes, 8);
    bytes = bytes.sublist(10, boxHeader.boxDataSize.clamp(0, bytes.length));
    for (var i = 0; i < blockCount; i++) {
      if (bytes.length < 10) break;
      final blockSize = _beU16(bytes, 0);
      final blockType = _beU32(bytes, 2);
      final language = parseLanguage(bytes.sublist(6, 8));
      final encoding = _beU16(bytes, 8);
      final payloadEnd = blockSize.clamp(10, bytes.length);
      final payload = bytes.sublist(10, payloadEnd);
      final payloadString = switch (encoding) {
        // 0x00: short array
        0x00 => _shortArrayString(payload),
        // 0x01: string (UTF-16BE)
        0x01 => payload.toUtf16BeString().trim(),
        // 0x101: artwork/icon
        _ => '0x${payload.toHex()}',
      };
      final blockTypeString = switch (blockType) {
        0x01 => 'Title',
        0x03 => 'Creation Time',
        0x04 => 'Software',
        0x0A => 'Track property',
        0x0B => 'Time zone',
        0x0C => 'Modification Time',
        _ => '0x${(blockType & 0xFF).toRadixString(16).padLeft(2, '0')}',
      };
      blocks.add(
        QuickTimeMetadataBlock(
          type: blockTypeString,
          value: payloadString,
          language: language,
        ),
      );
      bytes = bytes.sublist(blockSize.clamp(0, bytes.length));
    }
    return blocks;
  }

  /// 0x00 编码：short 数组，按 16 位有符号数展示（与 Kotlin 端 `joinToString` 一致）
  static String _shortArrayString(List<int> payload) {
    final units = <int>[];
    for (var i = 0; i + 1 < payload.length; i += 2) {
      final v = (payload[i] << 8) | payload[i + 1];
      units.add(v >= 0x8000 ? v - 0x10000 : v);
    }
    return units.join(', ');
  }

  // ISO 639 语言代码：3 组 5 bit，每组为字母 ASCII 码 - 0x60
  // e.g. 0x55c4 -> 10101 01110 00100 -> 21 14 4 -> "und"
  static String parseLanguage(List<int> bytes) {
    final i = (bytes[0] << 8) | bytes[1];
    final c1 = String.fromCharCode(((i >> 10) & 0x1F) + 0x60);
    final c2 = String.fromCharCode(((i >> 5) & 0x1F) + 0x60);
    final c3 = String.fromCharCode((i & 0x1F) + 0x60);
    return '$c1$c2$c3';
  }

  static int _beU16(List<int> b, int offset) => (b[offset] << 8) | b[offset + 1];

  static int _beU32(List<int> b, int offset) => (b[offset] << 24) | (b[offset + 1] << 16) | (b[offset + 2] << 8) | b[offset + 3];
}

/// MP4 盒头：前 4 字节为大小（大端），后 4 字节为类型
class BoxHeader {
  final int boxDataSize;
  final String boxType;

  BoxHeader(List<int> bytes) : boxDataSize = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3], boxType = String.fromCharCodes(bytes.sublist(4, 8));
}

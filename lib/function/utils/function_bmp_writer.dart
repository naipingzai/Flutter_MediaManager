import 'dart:typed_data';
import 'dart:ui' as ui;

/// BMP（无压缩 RGB24）编码器，移植自 Android `utils/BmpWriter.kt`，
/// 无平台依赖（仅依赖 Flutter 的 `ui.Image` 像素数据），可复用于任何目标。
class BmpWriter {
  BmpWriter._();

  static const _fileHeaderSize = 14;
  static const _infoHeaderSize = 40;
  static const _bytePerPixel = 3;

  /// 将 [image] 编码为 BMP 字节（自下而上、行按 4 字节对齐、BGR 顺序）。
  /// [rgba] 为 `image.toByteData(format: ImageByteFormat.rawRgba)` 的结果。
  static Uint8List writeRGB24(int width, int height, Uint8List rgba) {
    assert(rgba.length >= width * height * 4, 'rawRgba bytes should cover all pixels');
    final padPerRow = (4 - (width * _bytePerPixel) % 4) % 4;
    final biSizeImage = (width * _bytePerPixel + padPerRow) * height;
    final bfSize = _fileHeaderSize + _infoHeaderSize + biSizeImage;

    final header = ByteData(_fileHeaderSize + _infoHeaderSize);
    // file header
    header.setUint8(0, 0x42); // 'B'
    header.setUint8(1, 0x4D); // 'M'
    header.setUint32(2, bfSize, Endian.little);
    header.setUint32(6, 0); // reserved
    header.setUint32(10, _fileHeaderSize + _infoHeaderSize); // offBits
    // info header
    header.setUint32(14, _infoHeaderSize);
    header.setUint32(18, width, Endian.little);
    header.setUint32(22, height, Endian.little);
    header.setUint16(26, 1, Endian.little); // planes
    header.setUint16(28, _bytePerPixel * 8, Endian.little); // bit count
    header.setUint32(30, 0); // compression: BI_RGB
    header.setUint32(34, biSizeImage, Endian.little);
    header.setUint32(38, 0); // x pels per meter
    header.setUint32(42, 0); // y pels per meter
    header.setUint32(46, 0); // clr used
    header.setUint32(50, 0); // clr important

    final rowBytes = width * _bytePerPixel + padPerRow;
    final pixels = Uint8List(rowBytes * height);
    var row = height - 1;
    while (row >= 0) {
      // BMP 像素自下而上存储，将第 `row` 行（自上而下数）写入第 `height-1-row` 行
      final srcOffset = row * width * 4;
      final dstOffset = (height - 1 - row) * rowBytes;
      var column = 0;
      while (column < width) {
        final src = srcOffset + column * 4;
        final dst = dstOffset + column * _bytePerPixel;
        // RGBA -> BGR
        pixels[dst] = rgba[src + 2];
        pixels[dst + 1] = rgba[src + 1];
        pixels[dst + 2] = rgba[src];
        column++;
      }
      row--;
    }

    final output = Uint8List(bfSize);
    output.setAll(0, header.buffer.asUint8List());
    output.setAll(_fileHeaderSize + _infoHeaderSize, pixels);
    return output;
  }

  /// 便捷方法：直接从 Flutter 图片编码 BMP 字节
  static Future<Uint8List> writeImageRGB24(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw StateError('failed to get raw RGBA bytes from image ${image.width}x${image.height}');
    }
    return writeRGB24(image.width, image.height, byteData.buffer.asUint8List());
  }
}

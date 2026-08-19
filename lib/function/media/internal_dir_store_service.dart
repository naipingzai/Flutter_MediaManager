import 'dart:ui' as ui;
import 'dart:async';
import 'dart:io';

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/origins.dart';
import 'package:flutter_media_view/function/model/mime_types.dart';
import 'package:flutter_media_view/function/media/internal_dir_fetch_service.dart';
import 'package:flutter_media_view/function/media/store_service.dart';
import 'package:path_provider/path_provider.dart';

/// 内部目录数据源：替代 Fmv 原生 MediaStore 服务。
///
/// 符合「导入模型」：所有媒体都位于 app 内部私有目录 `<docs>/library`，
/// 不直接访问系统相册 / MediaStore。此实现跨平台（Android/iOS/Linux 通用）。
///
/// 目录结构：
///   `<docs>/library/`          图库根目录
///   `<docs>/library/<album>/`  相册子目录（可选）
class InternalDirMediaStoreService implements MediaStoreService {
  static const rootDirName = 'library';

  Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$rootDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ── 变更检测：内部目录由导入/同步托管，这里统一视为无外部变更 ──

  @override
  Future<List<int>> checkObsoleteContentIds(List<int?> knownContentIds) async => const [];

  @override
  Future<List<int>> checkObsoletePaths(Map<int?, String?> knownPathById) async => const [];

  @override
  Future<List<String>> getChangedUris(int sinceGeneration) async => const [];

  @override
  Future<int?> getGeneration() async => 0;

  @override
  Future<Uri?> scanFile(String path, String mimeType) async => null;

  @override
  Stream<FmvEntry> getEntries(Map<int?, int?> knownEntries, {String? directory}) async* {
    final root = await _root();
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final absPath = entity.path;
      final name = absPath.split('/').last;
      final mimeType = _mimeForName(name);
      if (mimeType == null) continue;

      final stat = await entity.stat();

      // 解码图片头获取真实尺寸（viewer 依赖非空 displaySize，否则显示 Oops）
      var width = 0, height = 0;
      if (mimeType.startsWith('image/')) {
        try {
          final bytes = await File(absPath).readAsBytes();
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          final header = await ui.ImageDescriptor.encoded(buffer);
          width = header.width;
          height = header.height;
          header.dispose();
          buffer.dispose();
        } catch (_) {
          // 解码失败保持 0，后续分析流程会填充
        }
      }
      yield FmvEntry(
        id: null,
        uri: 'file://$absPath',
        path: absPath,
        pageId: null,
        contentId: stableHash(absPath),
        sourceMimeType: mimeType,
        width: width,
        height: height,
        sourceRotationDegrees: 0,
        sizeBytes: stat.size,
        sourceTitle: name,
        dateAddedSecs: (stat.modified.millisecondsSinceEpoch / 1000).round(),
        dateModifiedMillis: stat.modified.millisecondsSinceEpoch,
        sourceDateTakenMillis: stat.modified.millisecondsSinceEpoch,
        durationMillis: null,
        trashed: false,
        origin: EntryOrigins.mediaStoreContent,
      );
    }
  }

  /// 稳定哈希（跨运行/平台一致），用于内部文件的 contentId 去重。
  static String? _mimeForName(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    const images = <String, String>{
      'jpg': MimeTypes.jpeg,
      'jpeg': MimeTypes.jpeg,
      'png': MimeTypes.png,
      'gif': MimeTypes.gif,
      'webp': MimeTypes.webp,
      'bmp': MimeTypes.bmp,
      'heic': MimeTypes.heic,
      'heif': MimeTypes.heif,
      'tiff': MimeTypes.tiff,
      'tif': MimeTypes.tiff,
      'avif': MimeTypes.avif,
      'ico': MimeTypes.ico,
      'svg': MimeTypes.svg,
    };
    const videos = <String, String>{
      'mp4': MimeTypes.mp4,
      'mkv': MimeTypes.mkv,
      'webm': MimeTypes.webm,
      'mov': MimeTypes.mov,
      'avi': MimeTypes.avi,
      'm4v': MimeTypes.m4s,
      '3gp': MimeTypes.v3gpp,
      'ts': MimeTypes.mp2ts,
      'mts': MimeTypes.mp2ts,
      'mpg': MimeTypes.mpeg,
      'mpeg': MimeTypes.mpeg,
    };
    if (images.containsKey(ext)) return images[ext];
    if (videos.containsKey(ext)) return videos[ext];
    return null;
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_media_view/function/media/internal_dir_media_store_service.dart';
import 'package:flutter_media_view/function/model/mime_types.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 导入系统：把系统文件导入到 app 内部私有目录 `<docs>/library`。
///
/// 这是整个应用的数据源头。所有功能都基于导入的这份文件副本，
/// 导入路径统一为 app 私有目录下新建的专属目录（[InternalDirMediaStoreService.rootDirName]）。
class ImportService {
  /// 在库目录下每个导入文件独立占一个相册子目录，便于归类与命名冲突处理。
  static const String _albumDirName = 'import';

  Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/${InternalDirMediaStoreService.rootDirName}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 通过系统文件选择器选取文件。
  ///
  /// 选择逻辑与复制分离，便于上层在拿到文件列表后展示复制进度。
  Future<List<PlatformFile>> pickFiles() async {
    final result = await FilePicker.pickFiles(allowMultiple: true, 
      
      type: FileType.custom,
      allowedExtensions: const [
        // images
        'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'tif', 'tiff', 'avif', 'ico', 'svg',
        // videos
        'mp4', 'mkv', 'webm', 'mov', 'avi', 'm4v', '3gp', 'ts', 'mts', 'mpg', 'mpeg',
      ],
    );
    return result?.files ?? const <PlatformFile>[];
  }

  /// 通过系统文件选择器选取文件，并复制到私有库目录。
  ///
  /// 返回 [ImportResult]，其中 [ImportResult.uris] 为成功导入后的 `file://` URI 列表，
  /// 可用来触发集合刷新。
  Future<ImportResult> importFromSystem() async {
    final files = await pickFiles();
    if (files.isEmpty) return const ImportResult(uris: [], importedCount: 0, failedCount: 0, cancelled: true);

    final uris = <String>[];
    await for (final uri in importFiles(files)) {
      uris.add(uri);
    }
    return ImportResult(
      uris: uris,
      importedCount: uris.length,
      failedCount: files.length - uris.length,
      cancelled: false,
    );
  }

  /// 手动（文件管理器）把文件放进库目录后的目录扫描识别由 [InternalDirMediaStoreService.getEntries] 完成，
  /// 这里仅在需要时提供重新扫描入口。
  Future<ImportResult> scanDirectory() async {
    final root = await _root();
    final uris = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.path.split('/').last;
      if (_mimeForName(name) == null) continue;
      uris.add('file://${entity.path}');
    }
    return ImportResult(uris: uris, importedCount: uris.length, failedCount: 0, cancelled: false);
  }

  /// 逐个把 [files] 复制到私有库目录，每成功一个就 [Stream.yield] 该文件的 `file://` URI。
  ///
  /// 上层可据此展示实时进度（已处理数/总数）。复制使用流式分块读写，
  /// 避免一次性读入内存导致主 isolate 卡顿。
  Stream<String> importFiles(List<PlatformFile> files) async* {
    final root = await _root();
    final albumDir = Directory('${root.path}/$_albumDirName');
    if (!await albumDir.exists()) {
      await albumDir.create(recursive: true);
    }

    for (final file in files) {
      final name = _safeName(file.name);
      var target = File('${albumDir.path}/$name');
      // 冲突时追加序号
      if (await target.exists()) {
        final dotIndex = name.lastIndexOf('.');
        final stem = dotIndex > 0 ? name.substring(0, dotIndex) : name;
        final ext = dotIndex > 0 ? name.substring(dotIndex) : '';
        var index = 1;
        while (await target.exists()) {
          target = File('${albumDir.path}/${stem}_$index$ext');
          index++;
        }
      }
      try {
        await _copyTo(file, target);
        yield 'file://${target.path}';
      } catch (e) {
        debugPrint('ImportService failed to import ${file.name}: $e');
      }
    }
  }

  Future<void> _copyTo(PlatformFile file, File target) async {
    final sourcePath = file.path;
    if (sourcePath != null && sourcePath.isNotEmpty) {
      // 分块流式复制，避免大文件一次性读入内存
      await File(sourcePath).openRead().pipe(target.openWrite());
    } else {
      final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) throw StateError('no data for picked file \${file.name}');
      await target.writeAsBytes(bytes, flush: true);
    }
  }

  String _safeName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'import_${DateTime.now().millisecondsSinceEpoch}' : sanitized;
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

@immutable
class ImportResult {
  final List<String> uris;
  final int importedCount;
  final int failedCount;
  final bool cancelled;

  const ImportResult({
    required this.uris,
    required this.importedCount,
    required this.failedCount,
    required this.cancelled,
  });
}

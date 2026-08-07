import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';

/// 文件导出工具类
///
/// **职责**：把本地文件导出到系统相册 / 系统下载目录。
///
/// **平台区分**：
/// - **Android**：图片 / 视频保存到相册（DCIM），需要 WRITE_EXTERNAL_STORAGE 权限
/// - **iOS**：图片 / 视频保存到相册，需要 NSPhotoLibraryAddUsageDescription 权限
/// - **Linux/Windows/macOS**：保存到用户下载目录（Downloads）
/// - **Web**：下载到浏览器默认目录
class ExportHelper {
  /// 导出单个文件到系统
  ///
  /// [filePath] 源文件路径（APP 内部沙箱）
  /// [fileName] 保存的文件名
  /// [isVideo] true=视频，false=图片
  ///
  /// 返回导出结果（成功路径 / 错误信息）
  static Future<ExportResult> exportToGallery({
    required String filePath,
    required String fileName,
    required bool isVideo,
  }) async {
    try {
      if (!File(filePath).existsSync()) {
        return ExportResult.failure('源文件不存在: $filePath');
      }

      if (kIsWeb) {
        // Web：触发下载（SaverGallery 在 web 上传 base64）
        final bytes = await File(filePath).readAsBytes();
        final res = await SaverGallery.saveImage(
          bytes,
          fileName: fileName,
          skipIfExists: false,
          quality: 100,
        );
        if (res.isSuccess) {
          return ExportResult.success('已保存到下载目录');
        }
        return ExportResult.failure(res.errorMessage ?? '保存失败');
      }

      if (Platform.isAndroid || Platform.isIOS) {
        // Android / iOS：保存到相册
        final bytes = await File(filePath).readAsBytes();
        // ★ saver_gallery v4 没有 saveVideo 方法，统一用 saveImage
        //   saveImage 内部会根据文件头自动判断是图片还是视频，
        //   iOS 的 Photos 框架和 Android 的 MediaStore 都能正确处理。
        final res = await SaverGallery.saveImage(
          bytes,
          fileName: fileName,
          skipIfExists: false,
          quality: 100,
        );
        if (res.isSuccess) {
          return ExportResult.success(
            Platform.isIOS ? '已保存到 iOS 相册' : '已保存到 Android 相册',
          );
        }
        return ExportResult.failure(res.errorMessage ?? '保存失败');
      }

      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        // Desktop：保存到 Downloads 目录
        final downloadsDir = await _getDownloadsDir();
        final destPath = '${downloadsDir.path}/$fileName';
        await File(filePath).copy(destPath);
        return ExportResult.success('已保存到下载目录: $destPath');
      }

      return ExportResult.failure('不支持的操作系统');
    } catch (e) {
      return ExportResult.failure('导出失败: $e');
    }
  }

  /// 批量导出到相册
  static Future<List<ExportResult>> exportBatchToGallery(
    List<({String filePath, String fileName, bool isVideo})> items,
  ) async {
    final results = <ExportResult>[];
    for (final item in items) {
      final res = await exportToGallery(
        filePath: item.filePath,
        fileName: item.fileName,
        isVideo: item.isVideo,
      );
      results.add(res);
    }
    return results;
  }

  /// 获取系统下载目录（Desktop）
  static Future<Directory> _getDownloadsDir() async {
    if (Platform.isWindows) {
      // Windows: %USERPROFILE%\Downloads
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        return Directory('$userProfile\\Downloads');
      }
    }
    if (Platform.isMacOS) {
      // macOS: ~/Downloads
      final home = Platform.environment['HOME'];
      if (home != null) {
        return Directory('$home/Downloads');
      }
    }
    if (Platform.isLinux) {
      // Linux: ~/Downloads
      final home = Platform.environment['HOME'];
      if (home != null) {
        return Directory('$home/Downloads');
      }
    }
    // 兜底：使用临时目录
    return getTemporaryDirectory();
  }

  /// 显示导出结果 SnackBar
  static void showResult(BuildContext context, ExportResult result) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            result.success ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class ExportResult {
  final bool success;
  final String message;
  ExportResult._(this.success, this.message);
  factory ExportResult.success(String message) => ExportResult._(true, message);
  factory ExportResult.failure(String message) => ExportResult._(false, message);
}

import 'dart:typed_data';
import '../models/post.dart';

/// 同步后端抽象接口
///
/// 定义数据同步的通用操作。当前实现：WebDAV。
/// 未来可扩展：本地文件夹同步、FTP、S3 等。
abstract class SyncBackend {
  /// 后端名称（用于日志和 UI 展示）
  String get name;

  /// 加载远程 JournalData
  Future<JournalData?> loadData();

  /// 保存 JournalData 到远程
  Future<void> saveData(JournalData data);

  /// 上传本地文件到远程
  Future<void> uploadFile(String localPath, String remoteUrl);

  /// 上传文件（带进度回调）
  Future<void> uploadFileWithProgress(
    String localPath,
    String remoteUrl, {
    void Function(double progress, String speedText)? onProgress,
  });

  /// 获取媒体文件 URL
  String? getMediaUrl(String fileName);

  /// 获取媒体基础 URL
  String? get mediaBaseUrl;

  /// 获取图片加载认证头
  Map<String, String> get imageHeaders;

  /// 加载用户资料
  Future<Map<String, dynamic>?> loadUserProfile();

  /// 保存用户资料
  Future<void> saveUserProfile({
    required String nickname,
    required String localAvatarPath,
  });

  /// 清除所有远程数据
  Future<void> clearAllData();

  /// 获取加密服务
  dynamic get encryption;
}

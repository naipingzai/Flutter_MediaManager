import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import 'encryption_service.dart';
import 'log_service.dart';
import 'webdav_service.dart';

/// 数据同步状态
enum SyncStatus {
  /// 未同步（灰色云朵）
  idle,

  /// 同步中（旋转箭头）
  syncing,

  /// 同步成功（绿色对勾）
  success,

  /// 同步失败（红色叉号）
  failed,
}

/// 最近一次同步摘要（点击同步成功按钮展示）
class SyncSummary {
  final DateTime lastSyncTime;
  final int uploadedCount;
  final int downloadedCount;
  final String? errorMessage;
  final int? errorStatusCode;

  const SyncSummary({
    required this.lastSyncTime,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.errorMessage,
    this.errorStatusCode,
  });
}

/// 数据快照信息（思源笔记风格）
class SnapshotInfo {
  final String name;
  final String path;
  final DateTime timestamp;
  final int postCount;

  const SnapshotInfo({
    required this.name,
    required this.path,
    required this.timestamp,
    required this.postCount,
  });

  String get displayTitle {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tsDay = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final diff = today.difference(tsDay).inDays;
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return '今日 $timeStr';
    if (diff == 1) return '昨日 $timeStr';
    if (diff < 7) return '$diff 天前 $timeStr';
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} $timeStr';
  }
}

/// 数据同步服务
///
/// - 三种数据状态：本地数据、云端数据、数据同步
/// - 同时提供数据快照管理（自动/手动/恢复）
///
/// 本服务管理：
/// - 本地数据（local_data/data.json + local_data/media）
/// - 云端同步（与 WebDAV 双向）
/// - 数据快照（local_data/snapshots，最多保留 10 个）
class SyncService {
  static const String _dataDirName = 'local_data';
  static const String _mediaDirName = 'media';
  static const String _snapshotsDirName = 'snapshots';
  static const String _dataFileName = 'data.json';
  static const String _profileFileName = 'profile.json';
  static const int _maxSnapshots = 10;

  LogService? _logService;
  EncryptionService? _encryption;
  Dio? _dio;

  // ★ 重构：WebDavService 作为可选注入（唯一桥梁）
  //   所有 WebDAV 操作都通过 SyncService 代理，外部不再直接依赖 WebDavService
  WebDavService? _webDavService;
  bool get hasCloudConnection => _webDavService != null;
  bool get encryptionEnabled => _encryption != null && _encryption!.isEncryptionEnabled;

  /// 加密服务（供 UI 层图片解密用）
  EncryptionService? get encryption => _encryption;

  /// 注入 WebDavService（登录成功后调用，退出登录时传 null）
  void setWebDavService(WebDavService? service) {
    _webDavService = service;
    if (service != null) {
      _encryption = service.encryption;
    }
  }

  /// 获取媒体认证请求头（供 UI 层图片加载用）
  Map<String, String> get imageHeaders => _webDavService?.imageHeaders ?? {};

  /// 获取云端媒体文件 URL
  String? getMediaUrl(String fileName) {
    return _webDavService?.getMediaUrl(fileName);
  }

  /// 获取云端媒体基础 URL
  String? get mediaBaseUrl => _webDavService?.config.mediaUrl;

  // ─── WebDAV 代理方法（对内使用，外部不应直接调用） ───

  /// 从云端加载 JournalData
  Future<JournalData?> loadRemoteData() async {
    if (_webDavService == null) return null;
    return await _webDavService!.loadJournalData();
  }

  /// 保存 JournalData 到云端（带锁保护）
  Future<void> saveRemoteData(JournalData data) async {
    if (_webDavService == null) return;
    await _webDavService!.saveJournalData(data);
  }

  /// 上传本地文件到云端
  Future<void> uploadToCloud(String localPath, String remoteUrl) async {
    if (_webDavService == null) return;
    await _webDavService!.uploadFile(localPath, remoteUrl);
  }

  /// 上传用户资料到云端
  Future<void> saveUserProfile({
    required String nickname,
    required String localAvatarPath,
  }) async {
    if (_webDavService == null) return;
    await _webDavService!.saveUserProfileWithDefaults(
      nickname: nickname,
      localAvatarPath: localAvatarPath,
    );
  }

  /// 加载云端用户资料
  Future<Map<String, dynamic>?> loadUserProfile() async {
    if (_webDavService == null) return null;
    return await _webDavService!.loadUserProfile();
  }

  /// 清除云端所有数据
  Future<void> clearCloudData() async {
    if (_webDavService == null) return;
    await _webDavService!.clearAllData();
  }

  /// 上传文件到云端（带进度回调）
  Future<void> uploadWithProgress(
    String localPath,
    String remoteUrl, {
    void Function(double progress, String speedText)? onProgress,
  }) async {
    if (_webDavService == null) return;
    await _webDavService!.uploadFileWithProgress(localPath, remoteUrl, onProgress: onProgress);
  }

  // ─── 一键同步（供 UI 层直接调用） ───

  /// 执行完整同步：推送本地数据到云端 + 拉取云端数据
  Future<bool> performFullSync({String? nickname, String? avatarPath}) async {
    if (_webDavService == null) return false;
    final data = await loadLocalData();
    if (data == null) return false;

    final ok = await _pushToCloudInternal(data, nickname: nickname, avatarPath: avatarPath);
    if (ok) {
      await createSnapshot(data);
    }
    return ok;
  }

  /// 内部推送实现（不再需要外部回调）
  Future<bool> _pushToCloudInternal(
    JournalData data, {
    String? nickname,
    String? avatarPath,
  }) async {
    if (_webDavService == null) return false;
    try {
      _setStatus(SyncStatus.syncing);
      _syncedCount = 0;
      _totalToSync = _localMediaFiles.length;
      _syncError = null;
      _syncErrorStatusCode = null;
      _currentFileName = null;
      _notifyStateChanged();

      var uploadedCount = 0;
      final mediaUrl = _webDavService!.config.mediaUrl;

      // 1. 上传本地媒体文件到云端
      for (final fileName in List<String>.from(_localMediaFiles)) {
        _currentFileName = fileName;
        try {
          final remoteUrl = '$mediaUrl/$fileName';
          final localPath = await getLocalMediaPath(fileName);
          final localFile = File(localPath);
          if (await localFile.exists()) {
            await _webDavService!.uploadFile(localPath, remoteUrl);
            uploadedCount++;
          }
        } catch (e) {
          _logService?.warn('推送失败: $fileName', detail: e.toString(), source: 'Sync');
        }
        _syncedCount++;
        _notifyStateChanged();
      }

      // 2. 上传用户资料
      try {
        await _webDavService!.saveUserProfileWithDefaults(
          nickname: nickname ?? '媒体管理',
          localAvatarPath: avatarPath ?? '',
        );
      } catch (e) {
        _logService?.warn('上传用户资料失败', detail: e.toString(), source: 'Sync');
      }

      // 3. 上传 data.json
      await _webDavService!.saveJournalData(data);

      _currentFileName = null;
      _pendingSync = false;
      _lastUploaded = uploadedCount;
      _lastDownloaded = 0;
      _lastSyncTime = DateTime.now();
      _lastSummary = SyncSummary(
        lastSyncTime: _lastSyncTime!,
        uploadedCount: uploadedCount,
        downloadedCount: 0,
      );
      _setStatus(SyncStatus.success);
      _logService?.success('同步完成', detail: '上传 $uploadedCount 个文件', source: 'Sync');
      return true;
    } catch (e) {
      _setStatus(SyncStatus.failed);
      _syncError = e.toString();
      _logService?.error('同步失败', detail: e.toString(), source: 'Sync');
      return false;
    }
  }

  // ─── 后台推送待同步数据 ───

  /// 后台推送（如果有待同步数据）
  Future<void> pushPendingData() async {
    if (_webDavService == null || !_pendingSync) return;
    final data = await loadLocalData();
    if (data == null) return;
    _logService?.info('后台推送待同步数据...', source: 'Sync');
    final ok = await _pushToCloudInternal(data);
    if (ok) _logService?.success('后台推送完成', source: 'Sync');
  }

  /// 后台拉取云端数据并合并
  Future<JournalData?> pullAndMerge({JournalData? localData}) async {
    if (_webDavService == null) return null;
    try {
      _setStatus(SyncStatus.syncing);
      _notifyStateChanged();

      final remote = await _webDavService!.loadJournalData();
      final merged = _mergeData(localData, remote);
      await saveLocalData(merged);

      _lastSyncTime = DateTime.now();
      _lastSummary = SyncSummary(
        lastSyncTime: _lastSyncTime!,
        uploadedCount: 0,
        downloadedCount: 0,
      );
      _setStatus(SyncStatus.success);
      return merged;
    } catch (e) {
      _setStatus(SyncStatus.failed);
      _syncError = e.toString();
      _logService?.error('拉取云端数据失败', detail: e.toString(), source: 'Sync');
      return null;
    }
  }

  bool _enabled = false;
  SyncStatus _syncStatus = SyncStatus.idle;
  int _syncedCount = 0;
  int _totalToSync = 0;
  String? _currentFileName;
  String? _syncError;
  int? _syncErrorStatusCode;
  DateTime? _lastSyncTime;
  int _lastUploaded = 0;
  int _lastDownloaded = 0;
  SyncSummary? _lastSummary;

  // 同步间隔（秒）
  int _syncIntervalSeconds = 60;
  int get syncIntervalSeconds => _syncIntervalSeconds;

  // 已同步到本地的媒体文件名集合
  final Set<String> _localMediaFiles = {};
  Set<String> get localMediaFiles => _localMediaFiles;

  // 回调
  VoidCallback? _onSyncStateChanged;

  bool get enabled => _enabled;
  SyncStatus get syncStatus => _syncStatus;
  int get syncedCount => _syncedCount;
  int get totalToSync => _totalToSync;
  String? get currentFileName => _currentFileName;
  String? get syncError => _syncError;
  int? get syncErrorStatusCode => _syncErrorStatusCode;
  DateTime? get lastSyncTime => _lastSyncTime;
  SyncSummary? get lastSummary => _lastSummary;

  set onSyncStateChanged(VoidCallback? callback) =>
      _onSyncStateChanged = callback;

  void setLogService(LogService? log) => _logService = log;
  void setEncryption(EncryptionService? enc) => _encryption = enc;

  void setSyncInterval(int seconds) {
    _syncIntervalSeconds = seconds.clamp(30, 300);
  }

  // 待同步标记
  bool _pendingSync = false;
  bool get pendingSync => _pendingSync;

  /// 标记有待同步数据
  Future<void> markPendingSync(bool value) async {
    _pendingSync = value;
    _logService?.info(value ? '已标记待同步' : '已同步', source: 'Sync');
  }

  void _setStatus(SyncStatus newStatus) {
    _syncStatus = newStatus;
    _notifyStateChanged();
  }

  void _notifyStateChanged() {
    _onSyncStateChanged?.call();
  }

  // ─── 目录管理 ───

  Future<Directory> _getDataDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_dataDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _getMediaDir() async {
    final dataDir = await _getDataDir();
    final dir = Directory('${dataDir.path}/$_mediaDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _getSnapshotsDir() async {
    final dataDir = await _getDataDir();
    final dir = Directory('${dataDir.path}/$_snapshotsDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ─── 本地数据读写 ───

  /// 读取本地 data.json
  Future<JournalData?> loadLocalData() async {
    try {
      final dataDir = await _getDataDir();
      final file = File('${dataDir.path}/$_dataFileName');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final data = JournalData.fromJson(json);
      _logService?.info('读取本地数据',
          detail: '${data.posts.length} 条动态', source: 'Sync');
      return data;
    } catch (e) {
      _logService?.warn('读取本地数据失败', detail: e.toString(), source: 'Sync');
      return null;
    }
  }

  /// 保存本地 data.json
  Future<void> saveLocalData(JournalData data) async {
    try {
      final dataDir = await _getDataDir();
      final file = File('${dataDir.path}/$_dataFileName');
      final content = jsonEncode(data.toJson());
      await file.writeAsString(content);
      _logService?.info('保存本地数据',
          detail: '${data.posts.length} 条动态', source: 'Sync');
    } catch (e) {
      _logService?.error('保存本地数据失败', detail: e.toString(), source: 'Sync');
    }
  }

  // ─── 本地媒体文件管理 ───

  /// 获取本地媒体文件路径
  Future<String> getLocalMediaPath(String fileName) async {
    final dir = await _getMediaDir();
    return '${dir.path}/$fileName';
  }

  /// 检查媒体文件是否已下载到本地
  bool isMediaLocal(String fileName) => _localMediaFiles.contains(fileName);

  /// 获取本地媒体文件
  Future<File?> getLocalMediaFile(String fileName) async {
    if (!_localMediaFiles.contains(fileName)) return null;
    final path = await getLocalMediaPath(fileName);
    final file = File(path);
    if (await file.exists()) return file;
    _localMediaFiles.remove(fileName);
    return null;
  }

  /// 保存媒体文件到本地（发布时调用）
  Future<void> saveMediaLocally(String fileName, Uint8List data) async {
    try {
      final path = await getLocalMediaPath(fileName);
      await File(path).writeAsBytes(data);
      _localMediaFiles.add(fileName);
      _logService?.info('保存到本地', detail: fileName, source: 'Sync');
    } catch (e) {
      _logService?.warn('本地保存失败: $fileName',
          detail: e.toString(), source: 'Sync');
    }
  }

  /// 下载媒体文件到本地（云端→本地）
  Future<String?> downloadMedia(
    String remoteUrl,
    String fileName,
    Map<String, String> httpHeaders,
  ) async {
    _dio ??= Dio();
    try {
      final response = await _dio!.get<List<int>>(
        remoteUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: httpHeaders,
        ),
      );

      var data = Uint8List.fromList(response.data!);

      // 解密（如果启用加密）
      if (_encryption != null && _encryption!.isEncryptionEnabled) {
        data = _encryption!.decryptBytes(data);
      }

      final path = await getLocalMediaPath(fileName);
      await File(path).writeAsBytes(data);
      _localMediaFiles.add(fileName);
      return path;
    } catch (e) {
      _logService?.warn('下载媒体失败: $fileName',
          detail: e.toString(), source: 'Sync');
      return null;
    }
  }

  /// 删除本地媒体文件
  Future<void> deleteMedia(String fileName) async {
    try {
      final path = await getLocalMediaPath(fileName);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      _localMediaFiles.remove(fileName);
      _logService?.info('删除本地媒体: $fileName', source: 'Sync');
    } catch (e) {
      _logService?.warn('删除本地媒体失败: $fileName',
          detail: e.toString(), source: 'Sync');
    }
  }

  // ─── 推送本地数据到云端 ───

  /// 推送本地数据到 WebDAV
  ///
  /// [saveProfileFn] 可选：用于上传用户资料（昵称/头像）到云端 profile.json
  Future<bool> pushToCloud({
    required Future<void> Function(String localPath, String remoteUrl) uploadFn,
    required Future<void> Function(JournalData data) saveDataFn,
    required String mediaBaseUrl,
    required JournalData data,
    Future<void> Function()? saveProfileFn,
  }) async {
    try {
      _setStatus(SyncStatus.syncing);
      _syncedCount = 0;
      _totalToSync = _localMediaFiles.length;
      _syncError = null;
      _syncErrorStatusCode = null;
      _currentFileName = null;
      _notifyStateChanged();

      var uploadedCount = 0;

      // 1. 上传本地媒体文件到云端
      for (final fileName in List<String>.from(_localMediaFiles)) {
        _currentFileName = fileName;
        try {
          final remoteUrl = '$mediaBaseUrl/$fileName';
          final localPath = await getLocalMediaPath(fileName);
          final localFile = File(localPath);
          if (await localFile.exists()) {
            await uploadFn(localPath, remoteUrl);
            uploadedCount++;
          }
        } catch (e) {
          _logService?.warn('推送失败: $fileName',
              detail: e.toString(), source: 'Sync');
        }
        _syncedCount++;
        _notifyStateChanged();
      }

      // 2. 上传用户资料（昵称/头像）到云端 profile.json
      //    如果没有头像，使用本地默认头像；昵称使用本地当前昵称
      if (saveProfileFn != null) {
        try {
          await saveProfileFn();
          _logService?.info('用户资料已上传', source: 'Sync');
        } catch (e) {
          _logService?.warn('上传用户资料失败', detail: e.toString(), source: 'Sync');
        }
      }

      // 3. 上传 data.json
      await saveDataFn(data);

      _currentFileName = null;
      _pendingSync = false;
      _lastUploaded = uploadedCount;
      _lastDownloaded = 0;
      _lastSyncTime = DateTime.now();
      _lastSummary = SyncSummary(
        lastSyncTime: _lastSyncTime!,
        uploadedCount: uploadedCount,
        downloadedCount: 0,
      );
      _setStatus(SyncStatus.success);
      _logService?.success('同步完成',
          detail: '上传 $uploadedCount 个文件', source: 'Sync');
      return true;
    } catch (e) {
      _setStatus(SyncStatus.failed);
      _syncError = e.toString();
      _logService?.error('同步失败', detail: e.toString(), source: 'Sync');
      return false;
    }
  }

  /// 拉取云端数据到本地
  Future<JournalData?> pullFromCloud({
    required Future<JournalData> Function() loadRemoteDataFn,
    required JournalData? localData,
  }) async {
    try {
      _setStatus(SyncStatus.syncing);
      _notifyStateChanged();

      final remote = await loadRemoteDataFn();

      // 合并：远程为基准 + 本地独有
      final merged = _mergeData(localData, remote);
      await saveLocalData(merged);

      _lastSyncTime = DateTime.now();
      _lastSummary = SyncSummary(
        lastSyncTime: _lastSyncTime!,
        uploadedCount: 0,
        downloadedCount: 0,
      );
      _setStatus(SyncStatus.success);
      return merged;
    } catch (e) {
      _setStatus(SyncStatus.failed);
      _syncError = e.toString();
      _logService?.error('拉取云端数据失败', detail: e.toString(), source: 'Sync');
      return null;
    }
  }

  JournalData _mergeData(JournalData? local, JournalData remote) {
    if (local == null) return remote;
    final remoteIds = remote.posts.map((p) => p.id).toSet();
    final localOnly =
        local.posts.where((p) => !remoteIds.contains(p.id)).toList();
    final merged = <Post>[...remote.posts, ...localOnly];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return JournalData(
      version: 1,
      lastModified: DateTime.now().toUtc(),
      posts: merged,
      syncMeta: remote.syncMeta,
    );
  }

  // ─── 数据快照（思源笔记风格）───

  /// 创建数据快照（自动快照在同步成功时调用）
  Future<void> createSnapshot(JournalData data) async {
    try {
      final snapshotsDir = await _getSnapshotsDir();
      final timestamp = DateTime.now();
      final name =
          'snap_${timestamp.year}${_pad(timestamp.month)}${_pad(timestamp.day)}_${_pad(timestamp.hour)}${_pad(timestamp.minute)}${_pad(timestamp.second)}.json';
      final file = File('${snapshotsDir.path}/$name');
      await file.writeAsString(jsonEncode(data.toJson()));

      // 只保留最近 N 个快照
      final files = snapshotsDir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (var i = _maxSnapshots; i < files.length; i++) {
        await files[i].delete();
      }
      _logService?.info('创建数据快照',
          detail: '$name (${data.posts.length} 条)', source: 'Sync');
    } catch (e) {
      _logService?.warn('创建快照失败', detail: e.toString(), source: 'Sync');
    }
  }

  /// 获取可用快照列表（按时间倒序）
  Future<List<SnapshotInfo>> listSnapshots() async {
    try {
      final snapshotsDir = await _getSnapshotsDir();
      final files = snapshotsDir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      final list = <SnapshotInfo>[];
      for (final f in files) {
        final name = f.path.split('/').last;
        final stem = name.replaceAll('snap_', '').replaceAll('.json', '');
        if (stem.length < 15) continue;
        final tsStr =
            '${stem.substring(0, 4)}-${stem.substring(4, 6)}-${stem.substring(6, 8)} ${stem.substring(9, 11)}:${stem.substring(11, 13)}:${stem.substring(13, 15)}';
        final ts = DateTime.tryParse(tsStr) ?? DateTime.now();
        int count = 0;
        try {
          final content = await f.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final posts = json['posts'] as List<dynamic>?;
          if (posts != null) count = posts.length;
        } catch (_) {}
        list.add(SnapshotInfo(
          name: name,
          path: f.path,
          timestamp: ts,
          postCount: count,
        ));
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  /// 从快照恢复数据（恢复前必须确认）
  Future<JournalData?> restoreSnapshot(String snapshotPath) async {
    try {
      final file = File(snapshotPath);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final data = JournalData.fromJson(json);
      // 恢复后保存为当前本地数据
      await saveLocalData(data);
      _logService?.success('快照恢复成功',
          detail: '${data.posts.length} 条动态', source: 'Sync');
      return data;
    } catch (e) {
      _logService?.error('快照恢复失败', detail: e.toString(), source: 'Sync');
      return null;
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  // ─── 初始化与清理 ───

  /// 初始化：扫描本地已存在的媒体文件
  Future<void> init() async {
    try {
      final dir = await _getMediaDir();
      final files = dir.listSync();
      _localMediaFiles.clear();
      for (final file in files) {
        if (file is File) {
          final name = file.path.split('/').last;
          _localMediaFiles.add(name);
        }
      }
      _logService?.info('本地数据初始化完成',
          detail: '${_localMediaFiles.length} 个文件', source: 'Sync');
    } catch (e) {
      _logService?.warn('本地数据初始化失败', detail: e.toString(), source: 'Sync');
    }
  }

  /// 下载缺失的本地媒体文件
  Future<void> syncDownload({
    required Future<List<String>> Function(String dirUrl) listRemoteFilesFn,
    required String mediaBaseUrl,
    required Map<String, String> imageHeaders,
    required List<String> allFileNames,
  }) async {
    if (!_enabled) return;
    if (_syncStatus == SyncStatus.syncing) return;

    _setStatus(SyncStatus.syncing);
    _syncedCount = 0;
    _totalToSync = 0;
    _syncError = null;
    _syncErrorStatusCode = null;
    _notifyStateChanged();

    try {
      final needDownload =
          allFileNames.where((n) => !_localMediaFiles.contains(n)).toList();
      _totalToSync = needDownload.length;

      if (needDownload.isEmpty) {
        _setStatus(SyncStatus.success);
        return;
      }

      var downloadedCount = 0;
      for (final fileName in needDownload) {
        _currentFileName = fileName;
        final url = '$mediaBaseUrl/$fileName';
        final result = await downloadMedia(url, fileName, imageHeaders);
        if (result != null) downloadedCount++;
        _syncedCount++;
        _notifyStateChanged();
      }

      _currentFileName = null;
      _lastUploaded = 0;
      _lastDownloaded = downloadedCount;
      _lastSyncTime = DateTime.now();
      _lastSummary = SyncSummary(
        lastSyncTime: _lastSyncTime!,
        uploadedCount: 0,
        downloadedCount: downloadedCount,
      );
      _setStatus(SyncStatus.success);
      _logService?.success('云端数据下载完成',
          detail: '$downloadedCount/${needDownload.length}', source: 'Sync');
    } catch (e) {
      _setStatus(SyncStatus.failed);
      _syncError = e.toString();
      _logService?.error('云端数据下载失败', detail: e.toString(), source: 'Sync');
    }
    _currentFileName = null;
    _notifyStateChanged();
  }

  /// 清理已被删除的本地媒体文件
  Future<void> cleanupLocal(List<String> activeFiles) async {
    try {
      final activeSet = activeFiles.toSet();
      final toRemove =
          _localMediaFiles.where((f) => !activeSet.contains(f)).toList();
      for (final fileName in toRemove) {
        await deleteMedia(fileName);
      }
      if (toRemove.isNotEmpty) {
        _logService?.info('本地数据清理完成',
            detail: '删除 ${toRemove.length} 个文件', source: 'Sync');
      }
    } catch (e) {
      _logService?.warn('本地数据清理异常', detail: e.toString(), source: 'Sync');
    }
  }

  /// 清除所有本地数据
  Future<void> clearAll() async {
    stopBackgroundTimer();
    try {
      final dir = await _getDataDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _localMediaFiles.clear();
      _setStatus(SyncStatus.idle);
      _lastSummary = null;
      _logService?.info('已清除本地数据', source: 'Sync');
    } catch (e) {
      _logService?.warn('清除本地数据失败', detail: e.toString(), source: 'Sync');
    }
  }

  /// 启用 / 停用同步
  void setEnabled(bool value) {
    _enabled = value;
    if (!value) {
      _setStatus(SyncStatus.idle);
      _syncedCount = 0;
      _totalToSync = 0;
    }
  }

  /// 本地数据总大小（字节）
  Future<int> getLocalDataSize() async {
    try {
      final dir = await _getDataDir();
      int size = 0;
      final files = dir.listSync(recursive: true);
      for (final file in files) {
        if (file is File) {
          size += await file.length();
        }
      }
      return size;
    } catch (_) {
      return 0;
    }
  }

  // ─── 后台同步定时器 ───

  Timer? _backgroundTimer;

  /// 启动后台同步定时器
  void startBackgroundSync(Future<List<String>> Function() activeFilesFn) {
    stopBackgroundTimer();
    _backgroundTimer = Timer.periodic(
      Duration(seconds: _syncIntervalSeconds),
      (_) async {
        if (!_enabled || _syncStatus == SyncStatus.syncing) return;
        try {
          final allFiles = await activeFilesFn();
          await cleanupLocal(allFiles);
        } catch (e) {
          _logService?.warn('后台同步异常', detail: e.toString(), source: 'Sync');
        }
      },
    );
    _logService?.info('后台同步已启动',
        detail: '间隔 ${_syncIntervalSeconds}s', source: 'Sync');
  }

  /// 停止后台同步定时器
  void stopBackgroundTimer() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }
}

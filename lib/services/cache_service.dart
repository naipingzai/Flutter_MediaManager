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

/// 同步状态
enum SyncStatus {
  idle,
  syncing,
  completed,
  error,
}

/// 本地数据同步服务（原 CacheService，升级为完整同步机制）
///
/// 本地存储完整数据（data.json + 媒体文件），与 WebDAV 同步。
/// 支持手动/自动同步、快照恢复。
class CacheService {
  static const String _dataDirName = 'local_data';
  static const String _mediaDirName = 'media';
  static const String _snapshotsDirName = 'snapshots';
  static const String _dataFileName = 'data.json';

  LogService? _logService;
  EncryptionService? _encryption;
  Dio? _dio;

  bool _enabled = false;
  SyncStatus _syncStatus = SyncStatus.idle;
  int _syncedCount = 0;
  int _totalToSync = 0;
  String? _syncError;

  // 同步间隔（秒）
  int _syncIntervalSeconds = 60;
  int get syncIntervalSeconds => _syncIntervalSeconds;

  // 已同步的媒体文件名集合
  final Set<String> _syncedMediaFiles = {};

  // 回调
  VoidCallback? _onSyncStateChanged;

  bool get enabled => _enabled;
  SyncStatus get syncStatus => _syncStatus;
  int get syncedCount => _syncedCount;
  int get totalToSync => _totalToSync;
  String? get syncError => _syncError;
  Set<String> get cachedFiles => _syncedMediaFiles;

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
    _logService?.info('同步标记: ${value ? "有待同步" : "已同步"}', source: 'Sync');
  }

  /// 推送本地数据到 WebDAV
  ///
  /// [uploadFn] 上传文件函数：(localPath, remoteUrl) => void
  /// [saveDataFn] 保存数据函数：(JournalData) => void
  Future<bool> pushToWebDav({
    required Future<void> Function(String localPath, String remoteUrl) uploadFn,
    required Future<void> Function(JournalData data) saveDataFn,
    required String mediaBaseUrl,
  }) async {
    try {
      _syncStatus = SyncStatus.syncing;
      _notifyStateChanged();

      // 1. 读取本地数据
      final localData = await loadLocalData();
      if (localData == null) {
        _syncStatus = SyncStatus.idle;
        _notifyStateChanged();
        return false;
      }

      // 2. 上传本地媒体文件到 WebDAV
      _totalToSync = _syncedMediaFiles.length;
      _syncedCount = 0;
      _notifyStateChanged();

      for (final fileName in _syncedMediaFiles) {
        try {
          final remoteUrl = '$mediaBaseUrl/$fileName';
          final localPath = await getLocalMediaPath(fileName);
          final localFile = File(localPath);
          if (await localFile.exists()) {
            await uploadFn(localPath, remoteUrl);
            _syncedCount++;
            _notifyStateChanged();
          }
        } catch (e) {
          _logService?.warn('推送媒体失败: $fileName', detail: e.toString(), source: 'Sync');
        }
      }

      // 3. 上传 data.json 到 WebDAV
      await saveDataFn(localData);
      
      // 清除待同步标记
      _pendingSync = false;
      _syncStatus = SyncStatus.completed;
      _notifyStateChanged();
      _logService?.success('推送同步完成', detail: '${_syncedCount}/${_totalToSync} 文件', source: 'Sync');
      return true;
    } catch (e) {
      _syncStatus = SyncStatus.error;
      _syncError = e.toString();
      _logService?.error('推送同步失败', detail: e.toString(), source: 'Sync');
      _notifyStateChanged();
      return false;
    }
  }

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) {
      _syncStatus = SyncStatus.idle;
      _syncedCount = 0;
      _totalToSync = 0;
      _notifyStateChanged();
    }
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
      _logService?.info('读取本地数据', detail: '${data.posts.length} 条动态', source: 'Sync');
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
      _logService?.info('保存本地数据', detail: '${data.posts.length} 条动态', source: 'Sync');
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

  /// 检查媒体文件是否已本地存在
  bool isMediaLocal(String fileName) => _syncedMediaFiles.contains(fileName);

  /// 获取本地媒体文件
  Future<File?> getLocalMediaFile(String fileName) async {
    if (!_syncedMediaFiles.contains(fileName)) return null;
    final path = await getLocalMediaPath(fileName);
    final file = File(path);
    if (await file.exists()) return file;
    _syncedMediaFiles.remove(fileName);
    return null;
  }

  /// 保存媒体文件到本地（上传时调用，保存原始数据）
  Future<void> saveMediaLocally(String fileName, Uint8List data) async {
    try {
      final path = await getLocalMediaPath(fileName);
      await File(path).writeAsBytes(data);
      _syncedMediaFiles.add(fileName);
      _logService?.info('本地保存媒体', detail: fileName, source: 'Sync');
    } catch (e) {
      _logService?.warn('本地保存媒体失败', detail: '$fileName: $e', source: 'Sync');
    }
  }

  /// 下载并保存媒体文件到本地
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
      _syncedMediaFiles.add(fileName);
      return path;
    } catch (e) {
      _logService?.warn('下载媒体失败: $fileName', detail: e.toString(), source: 'Sync');
      return null;
    }
  }

  // ─── 向后兼容方法 ───

  /// 获取本地路径（兼容旧接口）
  Future<String> getLocalPath(String fileName) => getLocalMediaPath(fileName);

  /// 检查是否已缓存（兼容旧接口）
  bool isCached(String fileName) => isMediaLocal(fileName);

  /// 获取缓存文件（兼容旧接口）
  Future<File?> getCachedFile(String fileName) => getLocalMediaFile(fileName);

  /// 获取或下载（兼容旧接口）
  Future<String?> getOrDownload(
    String remoteUrl,
    String fileName,
    Map<String, String> httpHeaders,
  ) async {
    final local = await getLocalMediaFile(fileName);
    if (local != null) return local.path;
    if (!_enabled) return null;
    return downloadMedia(remoteUrl, fileName, httpHeaders);
  }

  /// 下载并缓存（兼容旧接口）
  Future<String> downloadAndCache(
    String remoteUrl,
    String fileName,
    Map<String, String> httpHeaders,
  ) async {
    final result = await downloadMedia(remoteUrl, fileName, httpHeaders);
    if (result != null) return result;
    throw Exception('下载失败: $fileName');
  }

  /// 删除本地媒体文件
  Future<void> deleteMedia(String fileName) async {
    try {
      final path = await getLocalMediaPath(fileName);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      _syncedMediaFiles.remove(fileName);
      _logService?.info('删除本地媒体: $fileName', source: 'Sync');
    } catch (e) {
      _logService?.warn('删除本地媒体失败: $fileName', detail: e.toString(), source: 'Sync');
    }
  }

  /// 删除缓存（兼容旧接口）
  Future<void> deleteCache(String fileName) => deleteMedia(fileName);

  // ─── 快照功能 ───

  /// 创建数据快照
  Future<void> createSnapshot(JournalData data) async {
    try {
      final snapshotsDir = await _getSnapshotsDir();
      final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      final file = File('${snapshotsDir.path}/data_$timestamp.json');
      await file.writeAsString(jsonEncode(data.toJson()));

      // 只保留最近 10 个快照
      final files = snapshotsDir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (var i = 10; i < files.length; i++) {
        await files[i].delete();
      }
      _logService?.info('创建快照', detail: 'data_$timestamp.json', source: 'Sync');
    } catch (e) {
      _logService?.warn('创建快照失败', detail: e.toString(), source: 'Sync');
    }
  }

  /// 获取可用快照列表
  Future<List<Map<String, dynamic>>> listSnapshots() async {
    try {
      final snapshotsDir = await _getSnapshotsDir();
      final files = snapshotsDir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      return files.map((f) {
        final name = f.path.split('/').last;
        final timestampStr = name.replaceAll('data_', '').replaceAll('.json', '');
        final timestamp = int.tryParse(timestampStr) ?? 0;
        final dt = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
        return {
          'name': name,
          'path': f.path,
          'timestamp': dt.toLocal().toString().substring(0, 19),
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 从快照恢复数据
  Future<JournalData?> restoreSnapshot(String snapshotPath) async {
    try {
      final file = File(snapshotPath);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final data = JournalData.fromJson(json);
      // 恢复后保存为当前本地数据
      await saveLocalData(data);
      _logService?.success('快照恢复成功', detail: '${data.posts.length} 条动态', source: 'Sync');
      return data;
    } catch (e) {
      _logService?.error('快照恢复失败', detail: e.toString(), source: 'Sync');
      return null;
    }
  }

  // ─── 同步机制 ───

  /// 初始化：扫描本地已同步的媒体文件
  Future<void> init() async {
    try {
      final dir = await _getMediaDir();
      final files = dir.listSync();
      _syncedMediaFiles.clear();
      for (final file in files) {
        if (file is File) {
          final name = file.path.split('/').last;
          _syncedMediaFiles.add(name);
        }
      }
      _logService?.info('本地媒体初始化完成',
          detail: '${_syncedMediaFiles.length} 个文件', source: 'Sync');
    } catch (e) {
      _logService?.warn('本地媒体初始化失败', detail: e.toString(), source: 'Sync');
    }
  }

  /// 同步 WebDAV 媒体文件到本地
  ///
  /// 只下载本地没有的文件。
  Future<void> syncAll(
    Future<List<String>> Function(String dirUrl) listRemoteFiles,
    String mediaBaseUrl,
    Map<String, String> imageHeaders,
    List<String> allFileNames,
  ) async {
    if (!_enabled) return;
    if (_syncStatus == SyncStatus.syncing) return;

    _syncStatus = SyncStatus.syncing;
    _syncedCount = 0;
    _totalToSync = 0;
    _syncError = null;
    _notifyStateChanged();

    try {
      // 找出需要下载的文件（远程有但本地没有的）
      final needDownload =
          allFileNames.where((name) => !_syncedMediaFiles.contains(name)).toList();
      _totalToSync = needDownload.length;

      if (needDownload.isEmpty) {
        _syncStatus = SyncStatus.completed;
        _notifyStateChanged();
        return;
      }

      _logService?.info('开始同步媒体文件',
          detail: '需要下载 ${needDownload.length} 个文件', source: 'Sync');

      for (final fileName in needDownload) {
        try {
          final url = '$mediaBaseUrl/$fileName';
          await downloadMedia(url, fileName, imageHeaders);
          _syncedCount++;
          _notifyStateChanged();
        } catch (e) {
          _logService?.warn('同步失败: $fileName',
              detail: e.toString(), source: 'Sync');
        }
      }

      _syncStatus = SyncStatus.completed;
      _logService?.success('媒体同步完成',
          detail: '$_syncedCount/$_totalToSync', source: 'Sync');
    } catch (e) {
      _syncStatus = SyncStatus.error;
      _syncError = e.toString();
      _logService?.error('媒体同步异常', detail: e.toString(), source: 'Sync');
    }
    _notifyStateChanged();
  }

  /// 清理已删除帖子的本地媒体文件
  Future<void> syncCleanup(List<String> activeFiles) async {
    try {
      final activeSet = activeFiles.toSet();
      final toRemove = _syncedMediaFiles.where((f) => !activeSet.contains(f)).toList();
      for (final fileName in toRemove) {
        try {
          await deleteMedia(fileName);
        } catch (_) {}
      }
      if (toRemove.isNotEmpty) {
        _logService?.info('本地媒体清理完成',
            detail: '删除 ${toRemove.length} 个文件', source: 'Sync');
      }
    } catch (e) {
      _logService?.warn('媒体清理异常', detail: e.toString(), source: 'Sync');
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
      _syncedMediaFiles.clear();
      _logService?.info('已清除所有本地数据', source: 'Sync');
    } catch (e) {
      _logService?.warn('清除本地数据失败', detail: e.toString(), source: 'Sync');
    }
  }

  /// 获取本地数据总大小（字节）
  Future<int> getCacheSize() async {
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
  void startBackgroundSync(Future<List<String>> Function() syncFn) {
    stopBackgroundTimer();
    _backgroundTimer = Timer.periodic(
      Duration(seconds: _syncIntervalSeconds),
      (_) async {
        if (!_enabled || _syncStatus == SyncStatus.syncing) return;
        try {
          final allFiles = await syncFn();
          await syncCleanup(allFiles);
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

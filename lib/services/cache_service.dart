import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'encryption_service.dart';
import 'log_service.dart';

/// 本地缓存同步状态
enum SyncStatus {
  idle,
  syncing,
  completed,
  error,
}

/// 本地缓存服务
///
/// 将 WebDAV 上的媒体文件缓存到本地，减少网络请求，支持离线浏览。
/// 可通过设置项开启/关闭。
class CacheService {
  static const String _cacheDirName = 'media_cache';

  LogService? _logService;
  EncryptionService? _encryption;
  Dio? _dio;

  bool _enabled = false;
  SyncStatus _syncStatus = SyncStatus.idle;
  int _syncedCount = 0;
  int _totalToSync = 0;
  String? _syncError;
  
  // 后台同步间隔（秒）
  int _syncIntervalSeconds = 60;
  int get syncIntervalSeconds => _syncIntervalSeconds;
  
  void setSyncInterval(int seconds) {
    _syncIntervalSeconds = seconds.clamp(30, 300);
  }

  // 已缓存文件的文件名集合
  final Set<String> _cachedFiles = {};

  // 回调
  VoidCallback? _onSyncStateChanged;

  bool get enabled => _enabled;
  SyncStatus get syncStatus => _syncStatus;
  int get syncedCount => _syncedCount;
  int get totalToSync => _totalToSync;
  String? get syncError => _syncError;
  Set<String> get cachedFiles => _cachedFiles;

  /// 设置回调（当同步状态变化时通知 UI）
  set onSyncStateChanged(VoidCallback? callback) =>
      _onSyncStateChanged = callback;

  void setLogService(LogService? log) => _logService = log;
  void setEncryption(EncryptionService? enc) => _encryption = enc;

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) {
      _syncStatus = SyncStatus.idle;
      _syncedCount = 0;
      _totalToSync = 0;
      _notifyStateChanged();
    }
  }

  /// 获取本地缓存目录
  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDirName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 获取本地缓存文件路径
  Future<String> getLocalPath(String fileName) async {
    final dir = await _getCacheDir();
    return '${dir.path}/$fileName';
  }

  /// 检查文件是否已缓存
  bool isCached(String fileName) => _cachedFiles.contains(fileName);

  /// 获取本地缓存文件，如果没有则返回 null
  Future<File?> getCachedFile(String fileName) async {
    if (!_cachedFiles.contains(fileName)) return null;
    final path = await getLocalPath(fileName);
    final file = File(path);
    if (await file.exists()) return file;
    // 文件记录在缓存但实际不存在，移除记录
    _cachedFiles.remove(fileName);
    return null;
  }

  /// 获取缓存文件路径，如果没有缓存则下载后返回
  ///
  /// [remoteUrl] 远程文件完整 URL
  /// [fileName] 文件名（用于本地缓存路径）
  /// [httpHeaders] 认证头等
  Future<String?> getOrDownload(
    String remoteUrl,
    String fileName,
    Map<String, String> httpHeaders,
  ) async {
    // 已缓存
    final cached = await getCachedFile(fileName);
    if (cached != null) return cached.path;

    // 未开启缓存，直接返回 null（使用原始 URL）
    if (!_enabled) return null;

    // 下载并缓存
    try {
      return await downloadAndCache(remoteUrl, fileName, httpHeaders);
    } catch (e) {
      _logService?.warn('下载缓存文件失败: $fileName',
          detail: e.toString(), source: 'Cache');
      return null;
    }
  }

  /// 下载文件并缓存到本地
  Future<String> downloadAndCache(
    String remoteUrl,
    String fileName,
    Map<String, String> httpHeaders,
  ) async {
    _dio ??= Dio();

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

    final path = await getLocalPath(fileName);
    final file = File(path);
    await file.writeAsBytes(data);
    _cachedFiles.add(fileName);
    _logService?.info('缓存文件: $fileName', source: 'Cache');
    return path;
  }

  /// 删除本地缓存文件
  Future<void> deleteCache(String fileName) async {
    try {
      final path = await getLocalPath(fileName);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      _cachedFiles.remove(fileName);
      _logService?.info('删除缓存: $fileName', source: 'Cache');
    } catch (e) {
      _logService?.warn('删除缓存失败: $fileName',
          detail: e.toString(), source: 'Cache');
    }
  }

  /// 初始化：扫描本地缓存文件
  Future<void> init() async {
    try {
      final dir = await _getCacheDir();
      final files = dir.listSync();
      _cachedFiles.clear();
      for (final file in files) {
        if (file is File && !file.path.endsWith('.cache_meta.json')) {
          final name = file.path.split('/').last;
          _cachedFiles.add(name);
        }
      }
      _logService?.info('缓存初始化完成',
          detail: '${_cachedFiles.length} 个文件', source: 'Cache');
    } catch (e) {
      _logService?.warn('缓存初始化失败', detail: e.toString(), source: 'Cache');
    }
  }

  /// 同步 WebDAV 数据到本地缓存
  ///
  /// [webDavService] WebDAV 服务
  /// [mediaBaseUrl] 媒体文件基础 URL
  /// [imageHeaders] 认证头
  /// [allFileNames] 需要缓存的文件名列表
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
          allFileNames.where((name) => !_cachedFiles.contains(name)).toList();
      _totalToSync = needDownload.length;

      if (needDownload.isEmpty) {
        _syncStatus = SyncStatus.completed;
        _notifyStateChanged();
        return;
      }

      _logService?.info('开始同步缓存',
          detail: '需要下载 ${needDownload.length} 个文件', source: 'Cache');

      for (final fileName in needDownload) {
        try {
          final url = '$mediaBaseUrl/$fileName';
          await downloadAndCache(url, fileName, imageHeaders);
          _syncedCount++;
          _notifyStateChanged();
        } catch (e) {
          _logService?.warn('缓存同步失败: $fileName',
              detail: e.toString(), source: 'Cache');
        }
      }

      _syncStatus = SyncStatus.completed;
      _logService?.success('缓存同步完成',
          detail: '${_syncedCount}/${_totalToSync}', source: 'Cache');
    } catch (e) {
      _syncStatus = SyncStatus.error;
      _syncError = e.toString();
      _logService?.error('缓存同步异常', detail: e.toString(), source: 'Cache');
    }
    _notifyStateChanged();
  }

  /// 清理已删除帖子的缓存文件
  /// [activeFiles] 当前 WebDAV 上有效的文件名列表
  Future<void> syncCleanup(List<String> activeFiles) async {
    try {
      final activeSet = activeFiles.toSet();
      final toRemove = _cachedFiles.where((f) => !activeSet.contains(f)).toList();
      for (final fileName in toRemove) {
        try {
          final path = await getLocalPath(fileName);
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
          _cachedFiles.remove(fileName);
        } catch (e) {
          _logService?.warn('清理缓存失败: $fileName',
              detail: e.toString(), source: 'Cache');
        }
      }
      if (toRemove.isNotEmpty) {
        _logService?.info('缓存清理完成',
            detail: '删除 ${toRemove.length} 个文件', source: 'Cache');
      }
    } catch (e) {
      _logService?.warn('缓存清理异常', detail: e.toString(), source: 'Cache');
    }
  }

  /// 清除所有本地缓存
  Future<void> clearAll() async {
    stopBackgroundTimer();
    try {
      final dir = await _getCacheDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _cachedFiles.clear();
      _logService?.info('已清除所有缓存', source: 'Cache');
    } catch (e) {
      _logService?.warn('清除缓存失败', detail: e.toString(), source: 'Cache');
    }
  }

  /// 获取缓存总大小（字节）
  Future<int> getCacheSize() async {
    try {
      final dir = await _getCacheDir();
      int size = 0;
      final files = dir.listSync();
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

  // 后台同步定时器
  Timer? _backgroundTimer;
  
  /// 启动后台同步定时器
  /// [syncFn] 同步回调函数，返回当前所有有效文件名列表
  void startBackgroundSync(Future<List<String>> Function() syncFn) {
    stopBackgroundTimer();
    _backgroundTimer = Timer.periodic(
      Duration(seconds: _syncIntervalSeconds),
      (_) async {
        if (!_enabled || _syncStatus == SyncStatus.syncing) return;
        try {
          final allFiles = await syncFn();
          await syncCleanup(allFiles);
          // syncAll 会自动跳过已缓存文件
        } catch (e) {
          _logService?.warn('后台同步异常', detail: e.toString(), source: 'Cache');
        }
      },
    );
    _logService?.info('后台缓存同步已启动',
        detail: '间隔 ${_syncIntervalSeconds}s', source: 'Cache');
  }
  
  /// 停止后台同步定时器
  void stopBackgroundTimer() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  void _notifyStateChanged() {
    _onSyncStateChanged?.call();
  }
}

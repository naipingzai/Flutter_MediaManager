import 'sync_backend.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../models/post.dart';
import 'log_service.dart';
import 'encryption_service.dart';

/// WebDAV 连接测试结果
class ConnectionResult {
  final bool success;
  final String errorDetail;

  const ConnectionResult({required this.success, this.errorDetail = ''});

  @override
  String toString() => success ? 'success' : 'failed: $errorDetail';
}

/// 云端锁信息
class CloudLock {
  final String lockId;
  final String deviceId;
  final DateTime acquiredAt;
  final DateTime expiresAt;

  const CloudLock({
    required this.lockId,
    required this.deviceId,
    required this.acquiredAt,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
        'lockId': lockId,
        'deviceId': deviceId,
        'acquiredAt': acquiredAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };

  factory CloudLock.fromJson(Map<String, dynamic> json) => CloudLock(
        lockId: json['lockId'] as String? ?? '',
        deviceId: json['deviceId'] as String? ?? '',
        acquiredAt: DateTime.parse(json['acquiredAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
}

class _AvatarColor {
  final double r;
  final double g;
  final double b;
  const _AvatarColor(this.r, this.g, this.b);
}

/// WebDAV 服务客户端
class WebDavService implements SyncBackend {
  final WebDavConfig config;
  final Dio _dio;
  final String _authHeader;
  final Logger _logger = Logger();
  final EncryptionService _encryption = EncryptionService();
  LogService? _logService;
  bool _rawDataEnabled = false;

  /// 当前持有的锁
  CloudLock? _currentLock;

  /// 锁超时时间（秒）
  static const int _lockTimeoutSeconds = 60;

  /// 设备唯一标识
  String get _deviceId {
    // 使用配置哈希作为设备标识（简单实现）
    return config.serverUrl.hashCode.toString().substring(0, 8);
  }

  /// 外部注入的日志服务
  set logger(LogService? value) {
    _logService = value;
  }

  /// 设置原始数据上传开关
  void setRawDataEnabled(bool enabled) {
    _rawDataEnabled = enabled;
  }

  WebDavService(this.config)
      : _dio = Dio(),
        _authHeader = config.authHeaderValue {
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.followRedirects = true;
    _dio.options.maxRedirects = 5;
    // WebDAV 服务器可能因缺少 User-Agent 而拒绝请求
    _dio.options.headers = {
      'User-Agent': 'flutter_media_manager/1.0',
    };
    // 从用户凭证派生加密密钥
    _encryption.updateKeyFromCredential(
      serverUrl: config.serverUrl,
      username: config.username,
      token: config.token,
    );
    // 不设置 baseUrl，所有请求使用完整 URL
    // WebDAV 协议使用 207 (Multi-Status)、405 (Method Not Allowed) 等非标准码，
    // 需要扩展 validateStatus 避免 DioException 误抛
    _dio.options.validateStatus = (status) {
      if (status == null) return false;
      // 正常成功码 + WebDAV 特有码
      if (status >= 200 && status < 300) return true;
      if (status == 207) return true; // Multi-Status (PROPFIND)
      if (status == 404) return true; // Not Found（路径不存在，需自动创建）
      if (status == 405) return true; // Method Not Allowed（认证通过但方法被禁）
      // 其他状态码按默认处理（抛 DioException）
      return false;
    };

    // Android 端 HTTP 客户端兼容处理
    // 1. SSL 证书兼容：部分 WebDAV 服务器证书链在 Android 上验证失败
    // 2. 代理绕过：Android 系统可能配置了代理，干扰直连
    // 3. 直接创建 IOHttpClientAdapter 避免类型转换问题
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) {
            return true;
          }
          // 绕过系统代理，直连 WebDAV 服务器
          ..findProxy = (_) => 'DIRECT';
        return client;
      },
    );
  }

  /// 记录日志
  void _log(String title, {String? detail, bool error = false}) {
    _logService?.log(
      error ? LogLevel.error : LogLevel.info,
      title,
      detail: detail,
      source: 'WebDAV',
    );
  }

  /// 加密服务（供外部访问，如图片加载时解密）
  @override
  String get name => 'WebDAV';

  @override
  EncryptionService get encryption => _encryption;

  /// 通用请求头
  Map<String, String> get _headers => {
        'Authorization': _authHeader,
      };

  /// 供 UI 图片加载（CachedNetworkImage）使用的认证请求头
  ///
  /// WebDAV 服务器几乎都不允许匿名 GET，必须带上 Authorization
  /// 才能拿到上传后的图片/视频。否则会 401 导致图片黑屏。
  @override
  Map<String, String> get imageHeaders => {
        'Authorization': _authHeader,
      };

  // ─── 云端锁机制 ───

  String get _lockUrl => '${config.rootUrl}/.lock';

  /// 尝试获取云端锁
  ///
  /// 返回 true 表示成功获取锁，false 表示被其他设备锁定
  Future<bool> acquireLock() async {
    try {
      // 先检查现有锁
      final existingLock = await _readLock();
      if (existingLock != null && !existingLock.isExpired) {
        // 锁被其他设备持有且未过期
        if (existingLock.deviceId != _deviceId) {
          _log('云端锁被其他设备持有', detail: 'deviceId=${existingLock.deviceId}');
          return false;
        }
        // 是自己的锁，刷新过期时间
        await _writeLock(existingLock.lockId);
        return true;
      }

      // 创建新锁
      final lockId = DateTime.now().millisecondsSinceEpoch.toString();
      await _writeLock(lockId);
      _log('获取云端锁成功', detail: 'lockId=$lockId');
      return true;
    } catch (e) {
      _logService?.warn('获取云端锁失败', detail: e.toString());
      // 锁获取失败时，允许操作继续（降级策略）
      return true;
    }
  }

  /// 释放云端锁
  Future<void> releaseLock() async {
    try {
      await deleteFile(_lockUrl);
      _currentLock = null;
      _log('释放云端锁成功');
    } catch (e) {
      _logService?.warn('释放云端锁失败', detail: e.toString());
    }
  }

  /// 检查是否持有有效锁
  Future<bool> hasValidLock() async {
    if (_currentLock == null) return false;
    if (_currentLock!.isExpired) {
      // 锁已过期，尝试重新获取
      return await acquireLock();
    }
    return true;
  }

  Future<CloudLock?> _readLock() async {
    try {
      final content = await readFile(_lockUrl);
      if (content == null || content.isEmpty) return null;
      final json = jsonDecode(content) as Map<String, dynamic>;
      return CloudLock.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeLock(String lockId) async {
    final now = DateTime.now().toUtc();
    final lock = CloudLock(
      lockId: lockId,
      deviceId: _deviceId,
      acquiredAt: now,
      expiresAt: now.add(Duration(seconds: _lockTimeoutSeconds)),
    );
    _currentLock = lock;
    await writeFile(_lockUrl, jsonEncode(lock.toJson()));
  }

  // ─── 连接测试 ───

  /// 测试 WebDAV 连接（带超时保护）
  Future<bool> testConnection() async {
    final result = await testConnectionDetailed();
    return result.success;
  }

  /// 测试 WebDAV 连接，返回详细结果（带超时保护）
  Future<ConnectionResult> testConnectionDetailed() async {
    _log('测试 WebDAV 连接', detail: config.rootUrl);
    try {
      final testFut = _performTestDetailed();
      final result = await testFut.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _log('连接超时（30秒）', detail: config.rootUrl, error: true);
          return const ConnectionResult(
            success: false,
            errorDetail: '连接超时（30秒），请检查网络',
          );
        },
      );
      _log(result.success ? '连接测试成功' : '连接测试失败',
          detail: config.rootUrl, error: !result.success);
      return result;
    } catch (e) {
      _logService?.error('连接测试异常', detail: e.toString());
      _logger.e('WebDAV 连接测试异常: $e');
      return ConnectionResult(
        success: false,
        errorDetail: '连接异常: ${e.toString()}',
      );
    }
  }

  /// PROPFIND XML 请求体（123pan 等服务器要求提供）
  static const _propfindBody = '<?xml version="1.0" encoding="utf-8"?>'
      '<D:propfind xmlns:D="DAV:"><D:allprop/></D:propfind>';

  /// 实际执行测试逻辑（带详细错误信息）
  Future<ConnectionResult> _performTestDetailed() async {
    try {
      final response = await _dio.request(
        config.rootUrl,
        data: _propfindBody,
        options: Options(
          method: 'PROPFIND',
          headers: {
            ..._headers,
            'Depth': '0',
            'Content-Type': 'application/xml; charset=utf-8',
          },
          responseType: ResponseType.plain,
        ),
      );
      final code = response.statusCode;
      _log('PROPFIND 响应', detail: '状态码: $code');

      if (_isConnectSuccess(code)) {
        return const ConnectionResult(success: true);
      }

      if (code == 404) {
        final mkResult = await _tryMkcolRoot();
        return ConnectionResult(
          success: mkResult,
          errorDetail: mkResult ? '' : '路径不存在且无法创建',
        );
      }
      if (code == 401 || code == 403) {
        return ConnectionResult(
          success: false,
          errorDetail: '认证失败（状态码 $code），请检查用户名和密码',
        );
      }
      return ConnectionResult(
        success: false,
        errorDetail: '服务器返回状态码 $code',
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      _logService?.warn('PROPFIND 网络异常',
          detail: '${e.type.name}: ${e.message} ($code)');
      _logger.e('WebDAV 连接测试失败: ${e.type.name}: ${e.message} ($code)');

      if (code == 401 || code == 403) {
        return ConnectionResult(
          success: false,
          errorDetail: '认证失败（状态码 $code），请检查用户名和密码',
        );
      }
      return ConnectionResult(
        success: false,
        errorDetail: '网络异常: ${e.type.name} - ${e.message}',
      );
    }
  }

  /// 判断一个 HTTP 状态码是否表示 WebDAV 连接/认证成功
  bool _isConnectSuccess(int? code) {
    return code == 207 ||
        code == 200 ||
        code == 204 ||
        code == 301 ||
        code == 302 ||
        code == 405; // GET/PROPFIND 被禁用但认证通过了
  }

  /// rootPath 不存在时自动 MKCOL 创建，返回创建/认证是否成功
  Future<bool> _tryMkcolRoot() async {
    try {
      // 先用 MKCOL 创建目录（URL 必须以 / 结尾）
      final mkcolUrl = '${config.rootUrl}/';
      final mkcolResp = await _dio.request(
        mkcolUrl,
        options: Options(
          method: 'MKCOL',
          headers: _headers,
        ),
      );
      _log('MKCOL 响应', detail: '$mkcolUrl -> ${mkcolResp.statusCode}');
      // 201 Created, 200 OK, 405 Method Not Allowed (已存在) 都视为成功
      if (mkcolResp.statusCode == 201 ||
          mkcolResp.statusCode == 200 ||
          mkcolResp.statusCode == 405) {
        return true;
      }
      return false;
    } on DioException catch (e) {
      _logService?.warn('MKCOL 失败',
          detail: '${e.message} (${e.response?.statusCode})');
      // MKCOL 返回 405 也意味着目录已存在
      if (e.response?.statusCode == 405) {
        return true;
      }
      // MKCOL 401/403 说明认证失败
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return false;
      }
      // 其他错误，兑底检查父级 serverUrl 是否能连上
      return await _tryPropfindServer();
    } catch (_) {
      return await _tryPropfindServer();
    }
  }

  /// 兑底：PROPFIND 到 serverUrl（去除 rootPath）确认至少根目录可达
  Future<bool> _tryPropfindServer() async {
    try {
      final resp = await _dio.request(
        config.serverUrl,
        data: _propfindBody,
        options: Options(
          method: 'PROPFIND',
          headers: {
            ..._headers,
            'Depth': '0',
            'Content-Type': 'application/xml; charset=utf-8',
          },
          responseType: ResponseType.plain,
        ),
      );
      _log('PROPFIND 兑底响应',
          detail: '${config.serverUrl} -> ${resp.statusCode}');
      return _isConnectSuccess(resp.statusCode);
    } catch (_) {
      return false;
    }
  }

  /// 确保目录结构存在
  Future<void> ensureDirectoryStructure() async {
    _log('确保目录结构', detail: config.rootUrl);
    _log('目录结构延迟创建（首次写入时自动创建）');
  }

  /// 创建目录（MKCOL）
  Future<void> _mkcol(String url) async {
    try {
      final response = await _dio.request(
        url,
        options: Options(
          method: 'MKCOL',
          headers: _headers,
        ),
      );
      _log('MKCOL 成功', detail: '$url -> ${response.statusCode}');
    } on DioException catch (e) {
      _logService?.warn('MKCOL 失败',
          detail: '$url -> ${e.response?.statusCode}');
      _logger.w('MKCOL $url 失败: ${e.response?.statusCode}');
    }
  }

  /// 读取文本文件（自动解密）
  Future<String?> readFile(String url) async {
    try {
      // 加密模式：以 bytes 下载后解密
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          headers: _headers,
          responseType: ResponseType.bytes,
        ),
      );
      if (response.data == null) return null;
      return _encryption.decryptText(Uint8List.fromList(response.data!));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      _logService?.error('读取文件失败', detail: '$url - ${e.message}');
      _logger.e('读取文件失败 $url: ${e.message}');
      rethrow;
    }
  }

  /// 写入文本文件（自动加密 + 自动创建父目录）
  Future<void> writeFile(String url, String content) async {
    try {
      final data = _encryption.encryptText(content);

      await _dio.put(
        url,
        data: data,
        options: Options(
          headers: {
            ..._headers,
            'Content-Type': 'application/octet-stream',
          },
        ),
      );
      _log('写入文件成功', detail: url);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        _log('父目录不存在，先创建', detail: url);
        final dir = url.substring(0, url.lastIndexOf('/'));
        await _mkcol('$dir/');
        try {
          final retryData = _encryption.encryptText(content);

          await _dio.put(
            url,
            data: retryData,
            options: Options(
              headers: {
                ..._headers,
                'Content-Type': 'application/octet-stream',
              },
            ),
          );
          _log('重试写入成功', detail: url);
        } catch (e2) {
          _logService?.error('重试写入仍失败', detail: e2.toString());
          rethrow;
        }
      } else {
        _logService?.error('写入文件失败', detail: '$url - ${e.message}');
        rethrow;
      }
    } catch (e) {
      _logService?.error('写入异常', detail: e.toString());
      rethrow;
    }
  }

  /// 上传文件（自动加密 + 自动创建父目录）
  @override
  Future<void> uploadFile(String localPath, String remoteUrl) async {
    try {
      final file = File(localPath);
      final bytes = await file.readAsBytes();
      final data = _encryption.encryptBytes(Uint8List.fromList(bytes));
      await _dio.put(
        remoteUrl,
        data: data,
        options: Options(
          headers: {
            ..._headers,
            'Content-Type': 'application/octet-stream',
            'Content-Length': data.length,
          },
        ),
      );
      _log('上传文件成功', detail: '$localPath -> $remoteUrl');
      // 原始数据：上传一份不加密的媒体文件到 raw/ 目录（保持原始文件名）
      if (_rawDataEnabled) {
        final originalFileName = localPath.split('/').last;
        await _uploadRawData(originalFileName, Uint8List.fromList(bytes));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        _log('目录不存在，先创建', detail: remoteUrl);
        final dir = remoteUrl.substring(0, remoteUrl.lastIndexOf('/'));
        await _mkcol('$dir/');
        try {
          final file2 = File(localPath);
          final bytes2 = await file2.readAsBytes();
          final data2 = _encryption.encryptBytes(Uint8List.fromList(bytes2));

          await _dio.put(
            remoteUrl,
            data: data2,
            options: Options(
              headers: {
                ..._headers,
                'Content-Type': 'application/octet-stream',
                'Content-Length': data2.length,
              },
            ),
          );
          _log('重试上传成功', detail: remoteUrl);
        } catch (e2) {
          _logService?.error('重试上传失败', detail: e2.toString());
          rethrow;
        }
      } else {
        _logService?.error('上传文件失败', detail: '$localPath - ${e.message}');
        rethrow;
      }
    } catch (e) {
      _logService?.error('上传异常', detail: e.toString());
      rethrow;
    }
  }

  /// 上传文件（带进度和速度回调）
  @override
  Future<void> uploadFileWithProgress(
    String localPath,
    String remoteUrl, {
    void Function(double progress, String speedText)? onProgress,
  }) async {
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    final data = _encryption.encryptBytes(Uint8List.fromList(bytes));

    final startTime = DateTime.now();

    try {
      // Use Dio with onSendProgress for real progress
      await _dio.put(
        remoteUrl,
        data: data,
        options: Options(
          headers: {
            ..._headers,
            'Content-Type': 'application/octet-stream',
            'Content-Length': data.length,
          },
          sendTimeout: Duration(minutes: 10),
        ),
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            final elapsed = DateTime.now().difference(startTime).inMilliseconds;
            if (elapsed > 0) {
              final speed = sent / (elapsed / 1000); // bytes/sec
              final speedText = _formatSpeed(speed);
              onProgress(sent / total, speedText);
            }
          }
        },
      );
      _log('上传文件成功', detail: '$localPath -> $remoteUrl');
      // 原始数据
      if (_rawDataEnabled) {
        final originalFileName = localPath.split('/').last;
        await _uploadRawData(originalFileName, Uint8List.fromList(bytes));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final dir = remoteUrl.substring(0, remoteUrl.lastIndexOf('/'));
        await _mkcol('$dir/');
        await _dio.put(remoteUrl,
            data: data,
            options: Options(headers: {
              ..._headers,
              'Content-Type': 'application/octet-stream',
              'Content-Length': data.length
            }));
      } else {
        rethrow;
      }
    }
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// 下载文件（自动解密）
  Future<void> downloadFile(String remoteUrl, String localPath) async {
    try {
      final response = await _dio.get<List<int>>(
        remoteUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: _headers,
        ),
      );
      var data = Uint8List.fromList(response.data!);
      data = _encryption.decryptBytes(data);

      final file = File(localPath);
      await file.writeAsBytes(data);
      _log('下载文件成功', detail: '$remoteUrl -> $localPath');
    } catch (e) {
      _logService?.error('下载文件失败', detail: e.toString());
      rethrow;
    }
  }

  /// 删除文件
  Future<void> deleteFile(String url) async {
    try {
      await _dio.delete(url, options: Options(headers: _headers));
      _log('删除文件成功', detail: url);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _log('文件已不存在', detail: url);
        return;
      }
      _logService?.error('删除文件失败', detail: '$url - ${e.message}');
      rethrow;
    }
  }

  /// 列出目录下的文件名
  Future<List<String>> listFiles(String directoryUrl) async {
    try {
      final response = await _dio.request<String>(
        directoryUrl,
        data: _propfindBody,
        options: Options(
          method: 'PROPFIND',
          headers: {
            ..._headers,
            'Depth': '1',
            'Content-Type': 'application/xml; charset=utf-8',
          },
          responseType: ResponseType.plain,
        ),
      );
      return _parsePropfindResponse(response.data ?? '');
    } catch (e) {
      _logService?.error('列出文件失败', detail: e.toString());
      return [];
    }
  }

  /// 解析 PROPFIND XML 响应
  List<String> _parsePropfindResponse(String xml) {
    final files = <String>[];
    final regex = RegExp(r'<D:href>([^<]+)</D:href>', caseSensitive: false);
    final matches = regex.allMatches(xml);
    for (final match in matches) {
      final href = Uri.decodeComponent(match.group(1)!);
      final parts = href.split('/').where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        final fileName = parts.last;
        if (!fileName.endsWith('/') && fileName != 'data.json') {
          files.add(fileName);
        }
      }
    }
    return files;
  }

  /// 加载 JournalData
  Future<JournalData> loadJournalData() async {
    _log('加载 JournalData', detail: config.dataUrl);
    final content = await readFile(config.dataUrl);
    if (content == null || content.isEmpty) {
      _log('data.json 不存在，创建空数据库');
      final emptyData = JournalData.empty();
      await saveJournalData(emptyData);
      return emptyData;
    }
    // 兼容某些代理返回的错误文本（如 "Not Found"），避免解析失败
    final trimmed = content.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      _log('data.json 不存在或格式无效，返回空数据库');
      return JournalData.empty();
    }
    try {
      return JournalData.fromJson(jsonDecode(trimmed));
    } catch (e) {
      _logService?.error('解析 data.json 失败', detail: e.toString());
      return JournalData.empty();
    }
  }

  /// 保存 JournalData（加密版，带锁保护）
  Future<void> saveJournalData(JournalData data) async {
    // 尝试获取锁
    final hasLock = await acquireLock();
    if (!hasLock) {
      _logService?.warn('无法获取云端锁，跳过本次保存');
      throw Exception('云端数据被其他设备锁定，请稍后重试');
    }

    try {
      // 添加同步元数据
      final syncData = data.withNewSync();
      _log('保存 JournalData',
          detail:
              '${syncData.posts.length} 条帖子, syncId=${syncData.syncMeta?.syncId}');
      final json =
          const JsonEncoder.withIndent('  ').convert(syncData.toJson());
      await writeFile(config.dataUrl, json);
      // 原始数据模式：上传一份不加密的 data.json 到 raw/ 目录
      if (_rawDataEnabled) {
        await _uploadRawData('data.json', utf8.encode(json));
      }
    } finally {
      // 释放锁
      await releaseLock();
    }
  }

  /// 确保原始数据目录存在
  bool _rawDirCreated = false;

  Future<void> _ensureRawDir() async {
    if (_rawDirCreated) return;
    try {
      await _mkcol('${config.rootUrl}/raw/');
      _rawDirCreated = true;
    } catch (_) {}
  }

  /// 上传不加密的原始数据文件到 raw/ 目录
  Future<void> _uploadRawData(String fileName, List<int> data) async {
    try {
      await _ensureRawDir();
      final rawUrl = '${config.rootUrl}/raw/$fileName';
      await _dio.put(
        rawUrl,
        data: data,
        options: Options(
          headers: {
            ..._headers,
            'Content-Type': 'application/octet-stream',
          },
        ),
      );
      _log('原始数据上传成功', detail: rawUrl);
    } catch (e) {
      _logService?.warn('原始数据上传失败（不影响主流程）', detail: e.toString());
    }
  }

  /// 生成媒体文件名（格式：原文件名_日期_时间.扩展名）
  /// 示例：IMG_1234_20260731_153000.jpg
  String generateMediaFileName(String originalPath, {bool isVideo = false}) {
    final parts = originalPath.split('/');
    final fullName = parts.last; // e.g. IMG_1234.jpg
    final dotIdx = fullName.lastIndexOf('.');
    final nameWithoutExt =
        dotIdx > 0 ? fullName.substring(0, dotIdx) : fullName;
    final ext =
        dotIdx > 0 ? fullName.substring(dotIdx + 1).toLowerCase() : 'jpg';
    final now = DateTime.now();
    final ts = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    return '${nameWithoutExt}_$ts.$ext';
  }

  /// 获取媒体文件完整 URL
  @override
  String? getMediaUrl(String fileName) {
    return '${config.mediaUrl}/$fileName';
  }

  /// 保存用户资料到 WebDAV
  Future<void> saveUserProfileRaw(Map<String, dynamic> profile) async {
    _log('保存用户资料', detail: config.profileUrl);
    final json = jsonEncode(profile);
    await writeFile(config.profileUrl, json);
  }

  /// 同步本地用户资料到 WebDAV
  ///
  /// 如果本地没有头像（[localAvatarPath] 为空），则生成一张默认头像（取昵称首字）
  /// 并上传到云端。无论头像是否存在，都会保存 profile.json。
  @override
  Future<String> saveUserProfileWithDefaults({
    required String nickname,
    required String localAvatarPath,
  }) async {
    String? avatarFileName;
    String actualAvatarPath = localAvatarPath;

    // 1. 如果没有本地头像，生成默认头像（基于昵称首字）
    if (actualAvatarPath.isEmpty) {
      try {
        actualAvatarPath = await _generateDefaultAvatar(nickname);
        _log('已生成本地默认头像', detail: actualAvatarPath);
      } catch (e) {
        _logService?.warn('生成默认头像失败', detail: e.toString());
      }
    }

    // 2. 上传头像到云端
    if (actualAvatarPath.isNotEmpty && await File(actualAvatarPath).exists()) {
      try {
        avatarFileName = await uploadAvatar(actualAvatarPath);
      } catch (e) {
        _logService?.warn('上传头像失败', detail: e.toString());
      }
    }

    // 3. 保存 profile.json
    final profile = <String, dynamic>{
      'nickname': nickname,
      'avatarFileName': avatarFileName ?? '',
    };
    await saveUserProfileRaw(profile);
    _log('用户资料已同步到云端', detail: 'nickname=$nickname');
    return avatarFileName ?? '';
  }

  /// 生成默认头像：纯色背景（颜色由昵称哈希稳定生成）
  Future<String> _generateDefaultAvatar(String nickname) async {
    // 使用 path_provider 获取临时目录
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/default_avatar_${DateTime.now().millisecondsSinceEpoch}.png';

    // 用纯色背景 PNG 作为默认头像（颜色由昵称哈希稳定生成）
    final color = _colorFromString(nickname);
    final pngBytes = _buildColoredPng(120, color.r, color.g, color.b);
    final file = File(path);
    await file.writeAsBytes(pngBytes);
    return path;
  }

  _AvatarColor _colorFromString(String s) {
    // 用昵称的哈希生成稳定的色调
    int hash = 0;
    for (var i = 0; i < s.length; i++) {
      hash = (hash * 31 + s.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    final hue = (hash % 360).toDouble();
    final c = _hsvToRgb(hue, 0.55, 0.85);
    return _AvatarColor(c[0], c[1], c[2]);
  }

  List<double> _hsvToRgb(double h, double s, double v) {
    final c = v * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = v - c;
    double r = 0, g = 0, b = 0;
    if (h < 60) {
      r = c;
      g = x;
    } else if (h < 120) {
      r = x;
      g = c;
    } else if (h < 180) {
      g = c;
      b = x;
    } else if (h < 240) {
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      b = c;
    } else {
      r = c;
      b = x;
    }
    return [r + m, g + m, b + m];
  }

  /// 生成纯色 PNG（不依赖 image 包）
  /// 使用最小的 PNG 结构：IHDR + IDAT (使用 filter type 0) + IEND
  List<int> _buildColoredPng(int size, double r, double g, double b) {
    // 创建像素数据：每行前加 1 字节 filter type (0)
    final pixels = <int>[];
    for (var y = 0; y < size; y++) {
      pixels.add(0); // filter type
      for (var x = 0; x < size; x++) {
        pixels.add((r * 255).round());
        pixels.add((g * 255).round());
        pixels.add((b * 255).round());
      }
    }
    // 计算每段 IDAT（分段以避免单次 inflate 过大）
    final compressed = <int>[];
    const chunkSize = 65535;
    for (var off = 0; off < pixels.length; off += chunkSize) {
      final end = (off + chunkSize).clamp(0, pixels.length);
      final segment = pixels.sublist(off, end);
      compressed.addAll(_zlibStore(segment));
    }
    // 构建 PNG 文件
    final png = <int>[];
    png.addAll([137, 80, 78, 71, 13, 10, 26, 10]); // PNG 签名
    png.addAll(_pngChunk('IHDR', _ihdrData(size)));
    png.addAll(_pngChunk('IDAT', compressed));
    png.addAll(_pngChunk('IEND', []));
    return png;
  }

  List<int> _ihdrData(int size) {
    return [
      (size >> 24) & 0xFF,
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF,
      8, // bit depth
      2, // color type (RGB)
      0, // compression
      0, // filter
      0, // interlace
    ];
  }

  List<int> _pngChunk(String type, List<int> data) {
    final chunk = <int>[];
    final typeBytes = type.codeUnits;
    // CRC 校验
    final crcInput = <int>[...typeBytes, ...data];
    final crc = _crc32(crcInput);
    // length
    final len = data.length;
    chunk.add((len >> 24) & 0xFF);
    chunk.add((len >> 16) & 0xFF);
    chunk.add((len >> 8) & 0xFF);
    chunk.add(len & 0xFF);
    chunk.addAll(typeBytes);
    chunk.addAll(data);
    chunk.add((crc >> 24) & 0xFF);
    chunk.add((crc >> 16) & 0xFF);
    chunk.add((crc >> 8) & 0xFF);
    chunk.add(crc & 0xFF);
    return chunk;
  }

  /// 计算 CRC32（PNG 使用）
  int _crc32(List<int> bytes) {
    final table = _crc32Table;
    var crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc = table[(crc ^ b) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
  }

  /// zlib store（未压缩）封装，便于生成最小 PNG
  List<int> _zlibStore(List<int> data) {
    final out = <int>[];
    // zlib header: 0x78 0x01 (deflate, no compression)
    out.add(0x78);
    out.add(0x01);
    var offset = 0;
    while (offset < data.length) {
      final remain = data.length - offset;
      final blockLen = remain > 65535 ? 65535 : remain;
      // BTYPE=00 (stored)
      out.add(offset + blockLen == data.length ? 1 : 0);
      out.add(blockLen & 0xFF);
      out.add((blockLen >> 8) & 0xFF);
      out.add(~blockLen & 0xFF);
      out.add((~blockLen >> 8) & 0xFF);
      out.addAll(data.sublist(offset, offset + blockLen));
      offset += blockLen;
    }
    // adler32
    final adler = _adler32(data);
    out.add((adler >> 24) & 0xFF);
    out.add((adler >> 16) & 0xFF);
    out.add((adler >> 8) & 0xFF);
    out.add(adler & 0xFF);
    return out;
  }

  int _adler32(List<int> data) {
    var a = 1, b = 0;
    for (final byte in data) {
      a = (a + byte) % 65521;
      b = (b + a) % 65521;
    }
    return (b << 16) | a;
  }

  static final List<int> _crc32Table = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });

  /// 加载用户资料从 WebDAV
  ///
  /// 返回 null 表示 profile.json 不存在或格式无效（首次使用为正常情况）
  @override
  Future<Map<String, dynamic>?> loadUserProfile() async {
    _log('加载用户资料', detail: config.profileUrl);
    try {
      final content = await readFile(config.profileUrl);
      if (content == null || content.isEmpty) return null;
      // 兼容某些代理返回的错误文本（如 "Not Found"），避免被 jsonDecode 报错
      final trimmed = content.trim();
      if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
        // 文件不存在或返回了非 JSON 内容（首次使用时正常）
        return null;
      }
      return jsonDecode(trimmed) as Map<String, dynamic>;
    } catch (e) {
      _logService?.warn('加载用户资料失败', detail: e.toString());
      return null;
    }
  }

  /// 上传头像文件到 WebDAV
  Future<String?> uploadAvatar(String localPath) async {
    try {
      final ext = localPath.split('.').last.toLowerCase();
      final fileName = 'avatar.$ext';
      final remoteUrl = '${config.rootUrl}/$fileName';
      await uploadFile(localPath, remoteUrl);
      _log('头像上传成功', detail: remoteUrl);
      return fileName;
    } catch (e) {
      _logService?.error('头像上传失败', detail: e.toString());
      return null;
    }
  }

  /// 清除 WebDAV 上所有 APP 数据（媒体文件 + data.json + debug）
  @override
  String? get mediaBaseUrl => config.mediaUrl;

  @override
  Future<JournalData?> loadData() async {
    try {
      return await loadJournalData();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveData(JournalData data) async {
    await saveJournalData(data);
  }

  @override
  Future<void> saveUserProfile({
    required String nickname,
    required String localAvatarPath,
  }) async {
    await saveUserProfileWithDefaults(
      nickname: nickname,
      localAvatarPath: localAvatarPath,
    );
  }

  @override
  Future<void> clearAllData() async {
    _log('开始清除 WebDAV 数据', detail: config.rootUrl);

    // 1. 删除媒体文件
    try {
      final mediaFiles = await listFiles(config.mediaUrl);
      for (final fileName in mediaFiles) {
        try {
          final url = '${config.mediaUrl}/$fileName';
          await deleteFile(url);
        } catch (e) {
          _logService?.warn('删除媒体文件失败: $fileName', detail: e.toString());
        }
      }
      _log('媒体文件已清除', detail: '${mediaFiles.length} 个文件');
    } catch (e) {
      _logService?.warn('列出媒体文件失败', detail: e.toString());
    }

    // 2. 删除 data.json
    try {
      await deleteFile(config.dataUrl);
      _log('data.json 已删除');
    } catch (e) {
      _logService?.warn('删除 data.json 失败', detail: e.toString());
    }

    // 3. 删除原始数据目录文件
    try {
      final rawFiles = await listFiles('${config.rootUrl}/raw');
      for (final fileName in rawFiles) {
        try {
          await deleteFile('${config.rootUrl}/raw/$fileName');
        } catch (_) {}
      }
    } catch (_) {}

    // 4. 删除锁文件
    try {
      await deleteFile(_lockUrl);
    } catch (_) {}

    _log('WebDAV 数据清除完成');
  }
}

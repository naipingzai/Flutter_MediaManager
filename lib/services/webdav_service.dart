import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:logger/logger.dart';
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

/// WebDAV 服务客户端
class WebDavService {
  final WebDavConfig config;
  final Dio _dio;
  final String _authHeader;
  final Logger _logger = Logger();
  final EncryptionService _encryption = EncryptionService();
  LogService? _logService;
  bool _rawDataEnabled = false;

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
      'User-Agent': 'AdvanceMediaKB/1.0',
    };
    // 加密服务自动初始化（内部密码）
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
  EncryptionService get encryption => _encryption;

  /// 通用请求头
  Map<String, String> get _headers => {
        'Authorization': _authHeader,
      };

  /// 供 UI 图片加载（CachedNetworkImage）使用的认证请求头
  ///
  /// WebDAV 服务器几乎都不允许匿名 GET，必须带上 Authorization
  /// 才能拿到上传后的图片/视频。否则会 401 导致图片黑屏。
  Map<String, String> get imageHeaders => {
        'Authorization': _authHeader,
      };

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
      if (_encryption.isEncryptionEnabled) {
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
      } else {
        final response = await _dio.get<String>(
          url,
          options: Options(
            headers: _headers,
            responseType: ResponseType.plain,
          ),
        );
        return response.data;
      }
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
      final data = _encryption.isEncryptionEnabled
          ? _encryption.encryptText(content)
          : utf8.encode(content);
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
          final retryData = _encryption.isEncryptionEnabled
              ? _encryption.encryptText(content)
              : utf8.encode(content);
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
  Future<void> uploadFile(String localPath, String remoteUrl) async {
    try {
      final file = File(localPath);
      final bytes = await file.readAsBytes();
      final data = _encryption.isEncryptionEnabled
          ? _encryption.encryptBytes(Uint8List.fromList(bytes))
          : Uint8List.fromList(bytes);
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
          final data2 = _encryption.isEncryptionEnabled
              ? _encryption.encryptBytes(Uint8List.fromList(bytes2))
              : Uint8List.fromList(bytes2);
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
  Future<void> uploadFileWithProgress(
    String localPath,
    String remoteUrl, {
    void Function(double progress, String speedText)? onProgress,
  }) async {
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    final data = _encryption.isEncryptionEnabled
        ? _encryption.encryptBytes(Uint8List.fromList(bytes))
        : Uint8List.fromList(bytes);
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
        await _dio.put(remoteUrl, data: data,
            options: Options(headers: {..._headers, 'Content-Type': 'application/octet-stream', 'Content-Length': data.length}));
      } else {
        rethrow;
      }
    }
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
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
      if (_encryption.isEncryptionEnabled) {
        data = _encryption.decryptBytes(data);
      }
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
    try {
      return JournalData.fromJson(jsonDecode(content));
    } catch (e) {
      _logService?.error('解析 data.json 失败', detail: e.toString());
      return JournalData.empty();
    }
  }

  /// 保存 JournalData（加密版）
  Future<void> saveJournalData(JournalData data) async {
    // 添加同步元数据
    final syncData = data.withNewSync();
    _log('保存 JournalData', detail: '${syncData.posts.length} 条帖子, syncId=${syncData.syncMeta?.syncId}');
    final json = const JsonEncoder.withIndent('  ').convert(syncData.toJson());
    await writeFile(config.dataUrl, json);
    // 原始数据模式：上传一份不加密的 data.json 到 raw/ 目录
    if (_rawDataEnabled) {
      await _uploadRawData('data.json', utf8.encode(json));
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
    final nameWithoutExt = dotIdx > 0 ? fullName.substring(0, dotIdx) : fullName;
    final ext = dotIdx > 0 ? fullName.substring(dotIdx + 1).toLowerCase() : 'jpg';
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
  String getMediaUrl(String fileName) {
    return '${config.mediaUrl}/$fileName';
  }

  /// 保存用户资料到 WebDAV
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    _log('保存用户资料', detail: config.profileUrl);
    final json = jsonEncode(profile);
    await writeFile(config.profileUrl, json);
  }

  /// 加载用户资料从 WebDAV
  Future<Map<String, dynamic>?> loadUserProfile() async {
    _log('加载用户资料', detail: config.profileUrl);
    try {
      final content = await readFile(config.profileUrl);
      if (content == null || content.isEmpty) return null;
      return jsonDecode(content) as Map<String, dynamic>;
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

    _log('WebDAV 数据清除完成');
  }

}

import 'dart:convert';

/// 动态/帖子数据模型（WebDAV 云同步架构）
class Post {
  final String id;
  final String content;
  final List<String> mediaFiles; // WebDAV 远程文件名列表（图片）
  final String? videoFile; // 视频文件名
  final String? videoThumbnail; // 视频封面文件名
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Post({
    required this.id,
    required this.content,
    this.mediaFiles = const [],
    this.videoFile,
    this.videoThumbnail,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// 是否有视频
  bool get hasVideo => videoFile != null && videoFile!.isNotEmpty;

  /// 是否有任何媒体（图片/视频）
  bool get hasAnyMedia => mediaFiles.isNotEmpty || hasVideo;

  Post copyWith({
    String? id,
    String? content,
    List<String>? mediaFiles,
    String? videoFile,
    String? videoThumbnail,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Post(
      id: id ?? this.id,
      content: content ?? this.content,
      mediaFiles: mediaFiles ?? this.mediaFiles,
      videoFile: videoFile ?? this.videoFile,
      videoThumbnail: videoThumbnail ?? this.videoThumbnail,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'mediaFiles': mediaFiles,
      'videoFile': videoFile,
      'videoThumbnail': videoThumbnail,
      'tags': tags,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      mediaFiles: (json['mediaFiles'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      videoFile: json['videoFile'] as String?,
      videoThumbnail: json['videoThumbnail'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }
}

/// 同步元数据（用于多端冲突检测）
class SyncMeta {
  final String syncId; // 每次保存时生成的唯一 ID
  final DateTime lastSyncTime; // 最后同步时间（UTC）
  final String deviceId; // 设备标识
  final int editCount; // 编辑计数

  const SyncMeta({
    required this.syncId,
    required this.lastSyncTime,
    this.deviceId = '',
    this.editCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'syncId': syncId,
      'lastSyncTime': lastSyncTime.toUtc().toIso8601String(),
      'deviceId': deviceId,
      'editCount': editCount,
    };
  }

  factory SyncMeta.fromJson(Map<String, dynamic> json) {
    return SyncMeta(
      syncId: json['syncId'] as String? ?? '',
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.parse(json['lastSyncTime'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
      deviceId: json['deviceId'] as String? ?? '',
      editCount: json['editCount'] as int? ?? 0,
    );
  }

  factory SyncMeta.initial() {
    return SyncMeta(
      syncId: DateTime.now().millisecondsSinceEpoch.toString(),
      lastSyncTime: DateTime.now().toUtc(),
      editCount: 0,
    );
  }
}

/// 本地数据库文件格式（data.json）
///
/// 包含：版本号、最后修改时间、动态列表、用户资料、同步元数据。
/// 用户资料（昵称/头像）与动态数据统一存储、统一同步。
class JournalData {
  final int version;
  final DateTime lastModified;
  final List<Post> posts;
  final SyncMeta? syncMeta;

  /// 用户资料（昵称/头像文件名），随 data.json 一起同步
  final String nickname;
  final String avatarFileName;

  const JournalData({
    this.version = 1,
    required this.lastModified,
    required this.posts,
    this.syncMeta,
    this.nickname = '媒体管理',
    this.avatarFileName = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'lastModified': lastModified.toUtc().toIso8601String(),
      'posts': posts.map((p) => p.toJson()).toList(),
      'nickname': nickname,
      'avatarFileName': avatarFileName,
      if (syncMeta != null) 'syncMeta': syncMeta!.toJson(),
    };
  }

  factory JournalData.fromJson(Map<String, dynamic> json) {
    return JournalData(
      version: json['version'] as int? ?? 1,
      lastModified: DateTime.parse(json['lastModified'] as String),
      posts: (json['posts'] as List<dynamic>?)
              ?.map((p) => Post.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      syncMeta: json['syncMeta'] != null
          ? SyncMeta.fromJson(json['syncMeta'] as Map<String, dynamic>)
          : null,
      nickname: json['nickname'] as String? ?? '媒体管理',
      avatarFileName: json['avatarFileName'] as String? ?? '',
    );
  }

  factory JournalData.empty() {
    return JournalData(
      version: 1,
      lastModified: DateTime.now().toUtc(),
      posts: [],
      syncMeta: SyncMeta.initial(),
      nickname: '媒体管理',
      avatarFileName: '',
    );
  }

  /// 创建带新同步元数据的副本
  JournalData withNewSync({String deviceId = ''}) {
    final currentEdit = syncMeta?.editCount ?? 0;
    return JournalData(
      version: version,
      lastModified: DateTime.now().toUtc(),
      posts: posts,
      nickname: nickname,
      avatarFileName: avatarFileName,
      syncMeta: SyncMeta(
        syncId: DateTime.now().millisecondsSinceEpoch.toString(),
        lastSyncTime: DateTime.now().toUtc(),
        deviceId: deviceId,
        editCount: currentEdit + 1,
      ),
    );
  }

  /// 更新用户资料
  JournalData copyWith({
    String? nickname,
    String? avatarFileName,
    List<Post>? posts,
  }) {
    return JournalData(
      version: version,
      lastModified: DateTime.now().toUtc(),
      posts: posts ?? this.posts,
      syncMeta: syncMeta,
      nickname: nickname ?? this.nickname,
      avatarFileName: avatarFileName ?? this.avatarFileName,
    );
  }
}

/// 认证方式
enum AuthMethod {
  token, // Bearer Token（地址 + 令牌）
  basic, // Basic Auth（地址 + 用户名 + 密码）
}

/// WebDAV 连接配置
class WebDavConfig {
  final String serverUrl;
  final String token; // Bearer Token 或 App 密码
  final String username; // Basic Auth 用户名（可选）
  final String rootPath;
  final AuthMethod authMethod;
  const WebDavConfig({
    required this.serverUrl,
    required this.token,
    this.username = '',
    this.rootPath = '/flutter_media_manager',
    this.authMethod = AuthMethod.token,
  });

  String get rootUrl {
    final base = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    return '$base$rootPath';
  }

  String get mediaUrl => '$rootUrl/media';
  String get dataUrl => '$rootUrl/data.json';
  String get profileUrl => '$rootUrl/profile.json';

  /// 获取 Authorization 头的值
  String get authHeaderValue {
    if (authMethod == AuthMethod.basic) {
      return 'Basic ${base64Encode(utf8.encode('$username:$token'))}';
    } else {
      return 'Bearer $token';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'token': token,
      'username': username,
      'rootPath': rootPath,
      'authMethod': authMethod.index,
    };
  }

  factory WebDavConfig.fromJson(Map<String, dynamic> json) {
    // 兼容旧版配置（password 字段）
    final token = (json['token'] ?? json['password']) as String;
    return WebDavConfig(
      serverUrl: json['serverUrl'] as String,
      token: token,
      username: json['username'] as String? ?? '',
      rootPath: json['rootPath'] as String? ?? '/flutter_media_manager',
      authMethod: json['authMethod'] != null
          ? AuthMethod.values[json['authMethod'] as int? ?? 0]
          : AuthMethod.basic,
    );
  }
}

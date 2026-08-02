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

/// WebDAV 数据库文件格式
class JournalData {
  final int version;
  final DateTime lastModified;
  final List<Post> posts;

  const JournalData({
    this.version = 1,
    required this.lastModified,
    required this.posts,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'lastModified': lastModified.toUtc().toIso8601String(),
      'posts': posts.map((p) => p.toJson()).toList(),
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
    );
  }

  factory JournalData.empty() {
    return JournalData(
      version: 1,
      lastModified: DateTime.now().toUtc(),
      posts: [],
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

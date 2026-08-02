# WebDAV 架构设计方案

## 1. 概述

将「生活动态」从纯本地 SQLite 架构改造为 **WebDAV 云同步架构**。所有数据存储在 WebDAV 服务器上，支持多端（Windows/iOS/Android/macOS/Web）通过 WebDAV 协议读写同一数据，实现跨平台同步。

---

## 2. WebDAV 目录结构

```
/life-journal/                          # 根目录（用户可配置）
├── media/                              # 所有媒体文件（图片/视频）
│   ├── photo_20260729_093215_abc123.jpg
│   ├── photo_20260729_093216_def456.jpg
│   ├── video_20260729_101500_ghi789.mp4
│   └── ...
├── data.json                           # 动态数据库（JSON 格式）
└── .meta/
    └── app_info.json                   # 应用元信息
```

### 2.1 媒体文件命名规则
```
{类型}_{时间戳}_{UUID前6位}.{扩展名}

示例：
photo_20260729_093215_a1b2c3.jpg
photo_20260729_093216_d4e5f6.png
video_20260729_101500_g7h8i9.mp4
```

- **类型**：`photo` / `video`
- **时间戳**：`yyyyMMdd_HHmmss`
- **UUID前6位**：避免同秒内多文件冲突
- **扩展名**：保留原始文件扩展名

### 2.2 数据库格式 (data.json)

```json
{
  "version": 1,
  "lastModified": "2026-07-29T09:32:15Z",
  "posts": [
    {
      "id": "uuid-xxxx-xxxx",
      "content": "今天天气真好",
      "mediaFiles": [
        "photo_20260729_093215_a1b2c3.jpg",
        "photo_20260729_093216_d4e5f6.jpg"
      ],
      "tags": ["日常", "天气"],
      "createdAt": "2026-07-29T09:32:15Z",
      "updatedAt": "2026-07-29T09:32:15Z"
    }
  ]
}
```

### 2.3 应用元信息 (.meta/app_info.json)

```json
{
  "appName": "life-journal",
  "version": "1.0.0",
  "createdAt": "2026-07-29T00:00:00Z"
}
```

---

## 3. 技术架构

```
┌─────────────────────────────────────────────────────┐
│                      UI 层                          │
│  (保持现有页面设计不变)                               │
│  FeedScreen / CreatePost / Detail / Search / Profile │
├─────────────────────────────────────────────────────┤
│                   BLoC 状态层                       │
│  AppBloc（全局状态 + WebDAV连接状态）                 │
│  FeedBloc（动态CRUD + 同步）                         │
├─────────────────────────────────────────────────────┤
│                    仓库层                           │
│  PostRepository（接口）                              │
│  ├── WebDavPostRepository（WebDAV 实现）             │
│  └── LocalPostRepository（离线缓存，可选）           │
├─────────────────────────────────────────────────────┤
│                  WebDAV 客户端                      │
│  WebDavService                                      │
│  ├── 连接管理                                       │
│  ├── 文件操作（PUT/GET/DELETE/PROPFIND）             │
│  ├── 数据同步引擎                                   │
│  └── 冲突解决                                       │
└─────────────────────────────────────────────────────┘
```

---

## 4. WebDAV 操作协议

### 4.1 初始化连接
```
1. 用户输入：服务器地址、用户名、密码
2. APP 尝试 PROPFIND /life-journal/ 
3. 如果目录不存在 → MKCOL 创建目录结构
4. 如果 data.json 不存在 → 创建空数据库
5. 保存连接信息到 SharedPreferences
```

### 4.2 加载动态
```
1. GET /life-journal/data.json
2. 解析 JSON，构建 Post 列表
3. 媒体文件 URL = 服务器地址 + /life-journal/media/ + 文件名
4. 使用 cached_network_image 缓存远程图片
```

### 4.3 创建动态
```
1. 生成 Post UUID
2. 上传媒体文件：
   - 读取本地文件
   - 重命名为 photo_{timestamp}_{uuid6}.{ext}
   - PUT /life-journal/media/{filename}
3. 更新 data.json：
   - 读取当前 data.json
   - 添加新 Post
   - PUT /life-journal/data.json
4. 更新本地缓存
```

### 4.4 删除动态
```
1. 删除关联媒体文件：
   - DELETE /life-journal/media/{filename}
2. 更新 data.json（移除该 Post）
3. PUT /life-journal/data.json
```

### 4.5 搜索
```
在本地 data.json 缓存中搜索（content LIKE / tags LIKE）
```

---

## 5. Flutter WebDAV 实现

### 5.1 依赖
```yaml
dependencies:
  dio: ^5.4.0                    # HTTP 客户端（支持 WebDAV）
  xml: ^6.5.0                    # XML 解析（PROPFIND 响应）
  cached_network_image: ^3.4.1   # 远程图片缓存
  path: ^1.9.0
  uuid: ^4.5.1
  shared_preferences: ^2.3.2
```

### 5.2 WebDavService 核心接口

```dart
class WebDavService {
  // 连接配置
  String serverUrl;
  String username;
  String password;
  
  // 连接测试
  Future<bool> testConnection();
  
  // 目录操作
  Future<void> ensureDirectoryStructure();
  
  // 文件操作
  Future<String> readFile(String path);
  Future<void> writeFile(String path, String content);
  Future<void> uploadFile(String localPath, String remotePath);
  Future<void> downloadFile(String remotePath, String localPath);
  Future<void> deleteFile(String path);
  Future<List<String>> listFiles(String path);
  
  // 数据操作
  Future<List<Post>> loadAllPosts();
  Future<void> savePost(Post post, List<File> mediaFiles);
  Future<void> deletePost(String postId);
}
```

### 5.3 媒体文件处理流程

```
发布动态时：
1. 用户选择本地图片/视频
2. 生成远程文件名：photo_20260729_093215_a1b2c3.jpg
3. PUT 上传到 /life-journal/media/
4. Post.mediaFiles 记录远程文件名
5. 更新 data.json

显示图片时：
1. 从 Post.mediaFiles 获取文件名列表
2. 拼接完整 URL：{serverUrl}/life-journal/media/{filename}
3. 使用 CachedNetworkImage 显示（自动缓存）
```

---

## 6. 登录流程

```
启动APP
  ↓
检查本地是否有保存的 WebDAV 配置
  ↓
  ├─ 有 → 尝试连接 → 成功 → 进入主页
  │                    → 失败 → 显示连接错误 → 可选择重试或重新配置
  │
  └─ 无 → 显示登录页面
           ↓
         输入：服务器地址、用户名、密码
           ↓
         测试连接
           ↓
         成功 → 保存配置 → 进入主页
         失败 → 显示错误信息
```

---

## 7. 离线支持

```
- 首次加载：从 WebDAV 拉取 data.json，缓存到本地内存
- 创建动态：先写入本地内存，后台同步到 WebDAV
- 图片显示：使用 CachedNetworkImage 本地缓存
- 断网时：提示"同步中"，恢复网络后自动上传
```

---

## 8. 冲突解决策略

```
- 使用 data.json 的 lastModified 字段
- 写入前：GET 最新 data.json，检查 lastModified
- 如果 lastModified 比本地新 → 合并变更
- 如果冲突 → 以 WebDAV 上的为准（最后写入者胜）
- 未来可扩展：版本向量 / CRDT
```

---

## 9. 与现有代码的关系

### 保留
- 所有 UI 页面（FeedScreen, CreatePost, Detail, Search, Profile）
- 设计系统（app_theme, components）
- AppBloc 全局状态管理
- FeedBloc 事件/状态定义

### 替换
- `PostRepository` → `WebDavPostRepository`
- `LocalSettingsService` → 增加 WebDAV 配置存储
- `main.dart` → 增加登录页面判断
- `Post` 模型 → mediaPaths 改为 mediaFiles（远程文件名）

### 新增
- `lib/services/webdav_service.dart` — WebDAV 客户端
- `lib/repositories/webdav_post_repository.dart` — WebDAV 仓库实现
- `lib/ui/auth/login_screen.dart` — 登录页面
- `lib/functionality/auth/auth_bloc.dart` — 认证状态管理

---

## 10. 实施步骤

1. 添加 dio + xml 依赖
2. 实现 WebDavService
3. 实现 WebDavPostRepository
4. 创建登录页面
5. 改造 AppBloc 支持认证状态
6. 改造 FeedBloc 使用新仓库
7. 改造发布页面（上传文件到 WebDAV）
8. 改造图片显示（CachedNetworkImage）
9. 测试多端同步

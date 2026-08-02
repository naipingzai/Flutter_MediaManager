# 生活动态 APP 设计文档

## 1. 产品概述

**生活动态** 是一款基于 WebDAV 云同步的生活记录应用，类似小红书的瀑布流展示风格。用户可以在本地记录生活瞬间，支持文字、图片、视频、标签，所有数据加密存储在 WebDAV 服务器上，支持多端同步。

### 核心特点
- **WebDAV 云同步**：数据存储在 WebDAV 服务器上，支持多端访问
- **自动加密**：所有上传的数据和文件均以 AES-256-CBC 加密，WebDAV 服务端无法查看源文件
- **多平台**：支持 Android、iOS、Linux、Windows、macOS
- **无社交功能**：纯个人记录工具，无点赞、评论、关注等概念
- **调试备份**：上传时同时在 `debug/` 目录保存一份明文副本，方便验证数据

---

## 2. 页面结构

### 底部导航（3 个 Tab）

| Tab | 页面 | 说明 |
|-----|------|------|
| 🏠 首页 | FeedScreen | 动态信息流瀑布流 |
| 🔍 搜索 | DiscoverScreen | 搜索和标签筛选 |
| 👤 我的 | ProfileScreen | 统计、动态列表、设置 |

### 页面详情

#### 首页 (FeedScreen)
- 渐变图标 Logo + 标题 + 记录计数
- 瀑布流动态信息流，支持 1-4 列自适应
- 按标签筛选时显示筛选提示条（可清除）
- 右上角刷新按钮
- 右下角 FAB「发布」按钮
- 点击卡片进入详情

#### 动态详情 (PostDetailScreen)
- 媒体轮播查看（支持左右滑动、指示器）
- 点击图片进入全屏 PhotoView（双指缩放 + 左右滑动）
- 时间胶囊样式的时间显示
- 完整文字内容（可选中复制）+ 标签
- AppBar 右侧删除按钮

#### 发布动态 (CreatePostScreen)
- 文字输入 + 多图片/视频选择 + 标签输入
- 上传进度显示

#### 搜索 (DiscoverScreen)
- 搜索栏（内容和标签搜索）
- 热门标签展示（可点击筛选）
- 搜索结果列表

#### 我的 (ProfileScreen)
- 个人信息展示
- 统计卡片：动态数、媒体数、标签数
- 最近动态列表（可点击进入详情）
- 设置：
  - 主题模式（跟随系统 / 浅色 / 深色）
  - 默认列数（1-4 列）
  - 查看日志
  - 关于

#### 登录 (LoginScreen)
- WebDAV 连接配置
- 认证方式切换：令牌登录 / 账号密码（默认 Basic Auth）
- 服务器地址、存储路径配置
- 连接测试和错误诊断

---

## 3. UI 设计规范

### 圆角规范
- 所有卡片、容器统一使用 **16px** 圆角
- 标签容器使用 **8px** 圆角
- 标签筛选按钮使用 **16px** 圆角
- 图片缩略图使用 **12px** 圆角

### 主题
- 主色调：`#FF6B6B`（温暖的红色系）
- Material 3 设计语言
- 支持亮色 / 暗色 / 跟随系统
- 卡片风格：elevation=0 + outlineVariant 边框线

### 文字样式
- 使用 Material 3 语义样式 (textTheme)
- 标题：titleMedium/titleLarge (800 weight)
- 正文：bodyLarge (height 1.8) / bodySmall
- 标签：labelSmall
- 时间：labelSmall + onSurfaceVariant 色

---

## 4. 技术架构

```
┌──────────────────────────────────────────────────────┐
│                       UI 层                           │
│  lib/ui/                                             │
│  ├── auth/login_screen.dart         # WebDAV 登录     │
│  ├── home/home_screen.dart          # 主页容器        │
│  ├── feed/feed_screen.dart          # 瀑布流首页      │
│  ├── post/create_post_screen.dart   # 发布动态        │
│  ├── post/post_detail_screen.dart   # 动态详情        │
│  ├── discover/discover_screen.dart  # 搜索/发现       │
│  ├── profile/profile_screen.dart    # 个人中心        │
│  ├── viewer/viewer_page.dart        # 媒体查看器      │
│  └── widgets/encrypted_image.dart   # 加密图片组件    │
├──────────────────────────────────────────────────────┤
│                    状态管理层 (BLoC)                   │
│  lib/functionality/                                  │
│  ├── auth/auth_bloc.dart           # 认证状态         │
│  ├── home/app_bloc.dart            # 全局状态         │
│  └── feed/feed_bloc.dart           # 动态数据状态      │
├──────────────────────────────────────────────────────┤
│                     服务层                            │
│  lib/services/                                       │
│  ├── webdav_service.dart           # WebDAV 客户端    │
│  ├── encryption_service.dart       # AES-256 加密     │
│  ├── local_settings_service.dart   # 本地设置         │
│  └── log_service.dart              # 日志服务         │
├──────────────────────────────────────────────────────┤
│                     数据层                            │
│  lib/models/post.dart              # Post + WebDavConfig │
│  lib/utils/media_utils.dart        # 图片加载工具     │
└──────────────────────────────────────────────────────┘
```

### 状态管理（BLoC）

| BLoC | 职责 |
|------|------|
| **AuthBloc** | WebDAV 认证：连接测试、登录、登出、配置持久化 |
| **AppBloc** | 全局状态：主题、设置、导航索引 |
| **FeedBloc** | 动态数据：加载、创建、删除、搜索、标签筛选、列数、加密重存 |

### 数据模型

#### Post
| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | UUID |
| content | String | 文字内容 |
| mediaFiles | List<String> | WebDAV 远程文件名列表 |
| videoFile | String? | 视频文件名 |
| tags | List<String> | 标签列表 |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

#### JournalData
| 字段 | 类型 | 说明 |
|------|------|------|
| version | int | 数据格式版本 |
| lastModified | DateTime | 最后修改时间 |
| posts | List\<Post\> | 所有动态 |

#### WebDavConfig
| 字段 | 类型 | 说明 |
|------|------|------|
| serverUrl | String | WebDAV 服务器地址 |
| token | String | 认证密码/令牌 |
| username | String | Basic Auth 用户名 |
| rootPath | String | 存储路径（默认 /life-journal） |
| authMethod | AuthMethod | 认证方式（token/basic） |

---

## 5. 加密机制

### 自动加密（无需用户配置）
- **加密算法**：AES-256-CBC
- **密钥生成**：从内部固定密码通过 SHA-256 生成 256 位密钥
- **加密格式**：`[Magic "ENC1" (4字节)] + [IV (16字节)] + [密文]`
- **魔术标记**：文件前 4 字节为 `0x45 0x4E 0x43 0x31`（"ENC1"），用于区分加密和明文数据
- **向后兼容**：读取时自动检测魔术标记，无标记则作为明文处理

### WebDAV 存储结构
```
life-journal/
├── data.json                    # 加密版数据
├── media/
│   ├── photo_20260729_xxx.jpg   # 加密版媒体文件
│   └── video_20260729_xxx.mp4   # 加密版视频文件
└── debug/
    ├── data.json                # 明文 JSON（调试用）
    ├── photo_20260729_xxx.jpg   # 明文媒体文件（调试用）
    └── video_20260729_xxx.mp4   # 明文视频文件（调试用）
```

---

## 6. WebDAV 客户端特性

### 网络兼容性
- **SSL 证书兼容**：通过 `badCertificateCallback` 处理 Android 端证书链问题
- **代理绕过**：`findProxy` 返回 `DIRECT`，避免系统代理干扰
- **User-Agent**：设置 `AdvanceMediaKB/1.0`
- **PROPFIND XML**：123pan 等服务器要求提供请求体 `<D:propfind><D:allprop/></D:propfind>`
- **validateStatus**：扩展接受 WebDAV 特有的 207（Multi-Status）和 405（Method Not Allowed）

### 连接测试流程
1. PROPFIND rootUrl → 成功码 → 认证成功
2. PROPFIND rootUrl → 404 → MKCOL 自动创建目录
3. PROPFIND rootUrl → 401/403 → 认证失败
4. PROPFIND serverUrl → 兑底检查根目录可达性

### 详细错误诊断
- 连接超时：提示"连接超时（30秒），请检查网络"
- DNS 解析失败：提示"网络异常: connectionError - Failed host lookup"
- SSL 握手失败：提示"SSL 证书验证失败"
- 认证失败：提示"认证失败（状态码 401），请检查用户名和密码"

---

## 7. 依赖

| 包 | 用途 |
|------|------|
| flutter_bloc | 状态管理 |
| dio | HTTP 客户端（WebDAV 请求） |
| encrypt | AES-256 加密 |
| crypto | SHA-256 哈希 |
| cached_network_image | 网络图片缓存 |
| photo_view | 图片查看（双指缩放） |
| video_player | 视频播放 |
| shared_preferences | 本地设置存储 |
| image_picker | 图片/视频选择 |
| uuid | UUID 生成 |
| logger | 日志 |
| permission_handler | 权限管理 |
| dynamic_color | 动态主题色 |

---

## 8. 运行

```bash
flutter pub get
flutter run -d linux          # Linux 桌面
flutter run -d <device_id>    # Android
flutter build linux           # 编译 Linux
flutter build apk --release   # 编译 APK
```

## 9. 项目结构

```
lib/
├── main.dart                              # 入口 + MultiBlocProvider
├── models/post.dart                       # Post + JournalData + WebDavConfig + AuthMethod
├── services/
│   ├── webdav_service.dart                # WebDAV 客户端（加密上传/解密下载）
│   ├── encryption_service.dart            # AES-256-CBC 加密服务
│   ├── local_settings_service.dart        # 本地设置
│   └── log_service.dart                   # 日志服务
├── functionality/
│   ├── auth/
│   │   ├── auth_bloc.dart                 # 认证 BLoC
│   │   ├── auth_event.dart                # AuthCheck / AuthLogin / AuthLogout
│   │   └── auth_state.dart                # AuthStatus 枚举 + AuthState
│   ├── home/
│   │   ├── app_bloc.dart                  # 全局 BLoC
│   │   ├── app_event.dart
│   │   └── app_state.dart
│   └── feed/
│       ├── feed_bloc.dart                 # 动态 BLoC（含 FeedResaveEvent）
│       ├── feed_event.dart
│       └── feed_state.dart                # 含 encryptionEnabled 字段
├── ui/
│   ├── auth/login_screen.dart             # WebDAV 登录
│   ├── home/home_screen.dart              # 主页底部导航
│   ├── feed/feed_screen.dart              # 首页瀑布流
│   ├── post/create_post_screen.dart       # 发布动态
│   ├── post/post_detail_screen.dart       # 动态详情（加密图片轮播）
│   ├── discover/discover_screen.dart      # 搜索/发现
│   ├── profile/profile_screen.dart        # 个人中心 + 设置
│   ├── viewer/viewer_page.dart            # 本地媒体查看器
│   ├── widgets/encrypted_image.dart       # 加密网络图片组件
│   └── log/log_viewer_screen.dart         # 日志查看
├── utils/
│   ├── media_utils.dart                   # 图片加载工具（含加密解密）
│   └── error_helper.dart                  # 错误处理工具
└── core/
    ├── design_system/                     # 设计系统
    ├── i18n/                              # 国际化
    ├── format/                            # 格式化工具
    ├── navigation/                        # 路由
    └── permissions/                       # 权限服务
```

---

## 10. 平台特殊配置

### Android
- **INTERNET 权限**：`android/app/src/main/AndroidManifest.xml` 中声明
- **网络安全性**：`res/xml/network_security_config.xml` 信任系统和用户 CA 证书
- **NDK**：用于原生 C++ SQLite 数据库

### Linux
- 标准 GTK 窗口
- 使用 sqflite_common_ffi

### Web
- 通过 CORS 代理访问 WebDAV
- URL 参数预填配置

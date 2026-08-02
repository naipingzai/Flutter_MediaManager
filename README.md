# 生活动态

一款跨平台生活记录应用，通过 WebDAV 实现多端云同步，支持图片、视频、标签和加密存储。

## ✨ 核心功能

- **动态发布** — 文字 + 多图 + 视频，支持 `#标签` 自动识别
- **WebDAV 云同步** — 数据存储在 WebDAV 服务器，支持坚果云、123pan、Nextcloud 等
- **端到端加密** — 媒体文件和数据文件 AES 加密后存储
- **本地缓存** — 可配置同步间隔（30秒~5分钟），后台自动缓存媒体文件
- **多端支持** — Android、iOS、Linux、Web 四端统一
- **用户资料同步** — 头像和昵称存储在 WebDAV，新设备自动同步
- **全屏图片查看** — 双指缩放、左右滑动、下滑关闭，支持加密图片解密

## 📱 平台支持

| 平台 | 状态 | 说明 |
|------|------|------|
| Android | ✅ | APK 直接安装 |
| iOS | ✅ | IPA（需自行签名） |
| Linux | ✅ | 桌面端 |
| Web | ✅ | 浏览器访问（需 CORS 代理） |

## 🏗️ 技术架构

```
lib/
├── main.dart                    # 应用入口
├── models/
│   ├── post.dart                # 动态/帖子数据模型 + WebDavConfig
│   └── settings.dart            # 应用设置模型
├── services/
│   ├── webdav_service.dart      # WebDAV 客户端（连接、上传、下载、加密）
│   ├── cache_service.dart       # 本地缓存服务（后台同步、清理）
│   ├── encryption_service.dart  # AES 加密/解密
│   ├── local_settings_service.dart # 本地设置持久化
│   └── log_service.dart         # 日志服务
├── functionality/
│   ├── auth/                    # 认证 BLoC（WebDAV 登录）
│   ├── feed/                    # 动态 BLoC（CRUD、排序、筛选）
│   └── home/                    # 全局状态 BLoC（主题、设置、导航）
├── ui/
│   ├── auth/login_screen.dart   # WebDAV 登录页
│   ├── home/home_screen.dart    # 主页（底部导航）
│   ├── feed/feed_screen.dart    # 动态信息流
│   ├── post/
│   │   ├── create_post_screen.dart # 发布/编辑动态
│   │   └── post_detail_screen.dart # 动态详情（图片全屏、视频播放）
│   ├── profile/profile_screen.dart # 个人中心（设置、缓存管理）
│   ├── discover/discover_screen.dart # 发现/搜索页
│   └── log/log_viewer_screen.dart # 日志查看器
└── utils/
    └── media_utils.dart         # 媒体工具（缓存优先加载、加密解密）
```

### 状态管理

使用 **BLoC** 模式（flutter_bloc）：

- `AuthBloc` — WebDAV 认证状态管理
- `FeedBloc` — 动态列表 CRUD、排序、日期筛选、标签筛选
- `AppBloc` — 全局设置（主题、导航、用户资料）

### 数据存储

WebDAV 目录结构：

```
/flutter_media_manager/
├── data.json          # 动态数据（加密）
├── profile.json       # 用户资料（昵称等）
├── avatar.ext         # 头像文件
├── media/             # 媒体文件（加密）
│   ├── IMG_001_20260731_153000.jpg
│   ├── VID_002_20260731_153100.mp4
│   ├── VID_002_20260731_153100.thumb.jpg  # 视频封面
│   └── ...
└── debug/             # 调试备份（明文）
    ├── data.json
    └── ...
```

## 🚀 快速开始

### 环境要求

- Flutter 3.44.x (stable channel)
- Dart 3.x
- Android: JDK 17 + Android SDK
- iOS: Xcode 15+ (仅 macOS)
- Linux: `ninja-build` + `libgtk-3-dev`

### 编译运行

```bash
# 获取依赖
flutter pub get

# Android
flutter run -d android
flutter build apk --release

# iOS (需 macOS)
flutter build ios --release --no-codesign

# Linux
flutter run -d linux
flutter build linux --release

# Web
flutter run -d chrome
```

### WebDAV 配置

1. 启动 APP → 进入登录页
2. 选择认证方式（账号密码 或 令牌）
3. 输入 WebDAV 服务器地址、用户名、密码
4. 点击"连接"

支持的 WebDAV 服务：坚果云、123pan、Nextcloud、群晖 NAS、任意标准 WebDAV 服务器

## 📦 CI/CD

GitHub Actions 自动构建：

- **build-android** — Ubuntu 构建 APK
- **build-linux** — Ubuntu 构建 Linux bundle
- **build-ios** — macOS 构建 iOS（无签名 IPA）

## 🎯 功能实现状态

### ✅ 已完成

| 功能 | 说明 |
|------|------|
| WebDAV 连接与认证 | 支持 Basic Auth / Token，自动创建目录，连接测试 |
| 动态 CRUD | 创建、编辑、删除动态，支持文字+图片+视频 |
| 多图上传 | 选择多张图片，支持预览和删除 |
| 视频上传与播放 | 上传视频（带速度显示），生成封面缩略图，加密视频下载解密播放 |
| #标签 系统 | 内容中输入 `#标签名` 自动识别提取，标签高亮显示 |
| AES 端到端加密 | 媒体文件和数据文件加密存储 |
| 全屏图片查看 | 双指缩放、左右滑动、下滑关闭，支持加密图片解密 |
| 本地媒体缓存 | 可配置后台同步间隔（30s/1m/2m/3m/5m），自动跳过已缓存文件 |
| 缓存一致性 | 同步时自动清理已删除帖子的缓存文件 |
| 用户资料同步 | 头像上传 WebDAV，昵称存储到 profile.json，新设备自动同步 |
| 主题切换 | 浅色/深色/跟随系统，使用动态取色 |
| 排序与筛选 | 最新/最早/内容A-Z/媒体数排序，日期范围筛选，标签筛选 |
| 日志系统 | 实时日志查看、复制导出 |
| Android 全平台支持 | APK 构建，MainActivity 恢复，统一图标 |
| iOS 全平台支持 | IPA 构建（无签名），统一图标和名称 |
| Web 全平台支持 | CORS 代理支持，URL 参数预填 |
| Linux 全平台支持 | 桌面端构建 |
| GitHub Actions CI/CD | 三端自动构建 |
| 动态详情页 | 文字→媒体→时间+标签布局，不裁剪显示 |
| 统一 APP 名称 | 所有平台统一为「生活动态」 |

### 🔜 待开发

| 功能 | 优先级 | 说明 |
|------|--------|------|
| 相册管理 | 高 | 按时间/标签/日期分组浏览媒体文件 |
| 搜索全文索引 | 高 | 内容和标签的全文搜索优化 |
| 数据导出 | 中 | 导出为 Markdown / JSON / 相册打包 |
| 离线模式增强 | 中 | 无网络时仍可浏览和编辑，联网后自动同步 |
| 推送通知 | 低 | 新内容/同步状态提醒 |
| 地理位置标签 | 低 | 记录和显示动态的位置信息 |
| 动态分享 | 低 | 生成分享链接或图片卡片 |
| 批量操作 | 低 | 批量删除、批量标签管理 |
| 视频封面自定义 | 低 | 允许用户选择视频帧作为封面 |

## 📄 许可证

MIT

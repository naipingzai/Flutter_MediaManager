# 项目代码地图（CODE_MAP）

> 本文档面向"小白"开发者：详细列出 **每个 UI 文件、每个组件、每个接口、每段绘制代码的位置和作用**，方便您按图索骥修改代码。
>
> 工程遵循 `guide.skill` 规范：**本地数据 / 云端数据 / 数据同步 / 数据快照** 四态管理，**不存在"缓存"概念**。
>
> 圆角规范（按 guide.skill）：卡片 16 / 按钮 14 / 弹窗 20 / 输入框 14 / 媒体缩略图 16。

---

## 目录速查

| 路径 | 作用 |
|---|---|
| `lib/main.dart` | 应用入口 + 全局 Provider + 主题配置 |
| `lib/functionality/auth/` | 认证 Bloc（WebDAV 登录/登出/自动连接） |
| `lib/functionality/home/` | 全局 AppBloc（主题/设置） |
| `lib/functionality/feed/` | 动态 FeedBloc（加载/创建/编辑/删除/搜索） |
| `lib/services/sync_service.dart` | **数据同步服务**（本地/云端/同步/快照） |
| `lib/services/webdav_service.dart` | WebDAV HTTP 客户端 |
| `lib/services/encryption_service.dart` | AES-256-CBC 加密 |
| `lib/services/local_settings_service.dart` | SharedPreferences 持久化 |
| `lib/services/log_service.dart` | 日志服务（500 条上限） |
| `lib/models/post.dart` | 数据模型（Post/JournalData/WebDavConfig） |
| `lib/models/settings.dart` | 应用设置模型 |
| `lib/utils/media_utils.dart` | 图片加载工具 |
| `lib/utils/error_helper.dart` | 错误信息中文化 |
| `lib/ui/` | 所有页面 |
| `docs/guide.skill` | 设计规范 |
| `docs/CODE_MAP.md` | 本文档 |

---

## 1. `lib/main.dart` — 应用入口

| 行号 | 内容 | 说明 |
|---|---|---|
| 1-11 | import | flutter/material、media_kit、bloc、provider、dynamic_color |
| 13 | `Future<void> main()` | 入口：`WidgetsFlutterBinding.ensureInitialized()` + `MediaKit.ensureInitialized()`（视频播放） |
| 16 | `class LifeApp extends StatelessWidget` | 根 Widget |
| 18-72 | `build()` | 注入 Provider：`LogService`、`AuthBloc`、`AppBloc`、`SyncService`、`FeedBloc` |
| 53 | `cacheEnabled` → `syncEnabled` | 同步开关（按 guide.skill 命名） |
| 54 | `cacheSyncInterval` → `syncInterval` | 同步间隔 |
| 65-72 | `startBackgroundSync()` | 后台定时同步：清理已删除文件的本地副本 |
| 95-263 | `_buildLightTheme()` / `_buildDarkTheme()` | 全局 Material 3 主题 |
| 100-104 | `cardTheme: BorderRadius.circular(16)` | **卡片圆角 16** |
| 112 | `floatingActionButtonTheme: BorderRadius.circular(16)` | FAB 圆角 16 |
| 116-118 | `dialogTheme: BorderRadius.circular(20)` | **弹窗圆角 20** |
| 121 | `bottomSheetTheme: BorderRadius.vertical(top: Radius.circular(20))` | 底部弹层圆角 20 |
| 125 | `snackBarTheme: BorderRadius.circular(14)` | Snackbar 圆角 14 |
| 130 | `inputDecorationTheme: BorderRadius.circular(14)` | **输入框圆角 14** |
| 134-150 | `filledButtonTheme` / `outlinedButtonTheme` | 按钮圆角 14 |
| 254 | `_SplashScreen` | 启动画面（仅显示 Logo） |

**关键注入点**：
```dart
Provider<SyncService>(create: (_) => SyncService())  // L37
syncService.setEncryption(webDavService.encryption)   // L46
MediaUtils.syncService = syncService                 // L34 媒体工具绑定
```

---

## 2. `lib/services/sync_service.dart` — 数据同步核心服务

> 取代旧的 `CacheService`。本服务是整个 APP 数据的"中枢"。

### 2.1 状态枚举与模型（L11-90）

| 名称 | 行号 | 说明 |
|---|---|---|
| `enum SyncStatus` | L11-26 | `idle`(未同步/灰云) / `syncing`(同步中/旋转) / `success`(成功/绿对勾) / `failed`(失败/红叉) |
| `class SyncSummary` | L29-50 | 同步摘要：时间 + 上传数 + 下载数 + 错误信息 |
| `class SnapshotInfo` | L53-90 | 快照信息：路径/时间/动态数。`displayTitle` 自动生成 "今日 HH:mm" / "昨日 HH:mm" / "N 天前 HH:mm" / "YYYY-MM-DD HH:mm" |

### 2.2 `class SyncService` 核心方法（L94-666）

| 方法 | 行号 | 签名/作用 |
|---|---|---|
| 目录管理 | L121-148 | `_getDataDir()` → `~/local_data/`；`_getMediaDir()` → `~/local_data/media/`；`_getSnapshotsDir()` → `~/local_data/snapshots/` |
| `loadLocalData()` | L155-167 | 读取本地 `data.json`，无则返回 null |
| `saveLocalData(data)` | L170-183 | 保存 `data.json` 到本地 |
| `getLocalMediaPath(name)` | L187-189 | 返回 `~/local_data/media/{name}` |
| `isMediaLocal(name)` | L191 | 文件是否在本地 |
| `getLocalMediaFile(name)` | L193-200 | 取本地 File，不存在则从索引移除 |
| `saveMediaLocally(name, bytes)` | L202-213 | 保存字节到本地 |
| `downloadMedia(url, name, headers)` | L215-237 | 从云端下载并解密到本地 |
| `deleteMedia(name)` | L239-251 | 删除本地媒体文件 |
| **`pushToCloud(...)`** | L256-322 | **推送本地数据到云端**。参数：`uploadFn`(上传函数)、`saveDataFn`(保存 data.json)、`mediaBaseUrl`、`data` |
| `pullFromCloud(...)` | L324-348 | 拉取云端数据合并到本地 |
| `createSnapshot(data)` | L354-378 | **创建数据快照**（最多保留 10 个） |
| `listSnapshots()` | L380-420 | 列出所有快照（按时间倒序） |
| `restoreSnapshot(path)` | L422-440 | **从快照恢复**（恢复前应用层必须弹确认框） |
| `init()` | L444-466 | 启动时扫描本地媒体目录 |
| `syncDownload(...)` | L468-525 | 拉取云端缺失文件 |
| `cleanupLocal(activeFiles)` | L527-545 | 清理已删除帖子的本地文件 |
| `clearAll()` | L547-564 | 清除所有本地数据 |
| `setEnabled(bool)` | L566-575 | 启用/停用同步 |
| `getLocalDataSize()` | L577-592 | 返回本地数据总字节数 |
| `startBackgroundSync(activeFilesFn)` | L600-621 | 启动定时清理 |
| `stopBackgroundTimer()` | L623-626 | 停止定时器 |

### 2.3 关键状态变更点

```dart
// 状态变更（UI 通过 watch 监听）
setStatus(SyncStatus.syncing)  // 开始同步
setStatus(SyncStatus.success)  // 完成
setStatus(SyncStatus.failed)   // 失败（带 syncError）
setStatus(SyncStatus.idle)     // 重置

// UI 订阅
sync.onSyncStateChanged = () => setState((){});
```

---

## 3. `lib/services/webdav_service.dart` — WebDAV HTTP 客户端

| 方法 | 行号 | 作用 |
|---|---|---|
| `class ConnectionResult` | L12-20 | 连接测试结果（success/errorDetail） |
| `class CloudLock` | L23-51 | 云端锁机制（防止多端并发写） |
| `class WebDavConfig` | 在 `models/post.dart` | 服务器配置 |
| `testConnection()` / `testConnectionDetailed()` | L242-273 | 测试连接（带 30 秒超时） |
| `readFile(url)` | L435-464 | 读文件（自动解密） |
| `writeFile(url, content)` | L467-515 | 写文件（自动加密 + 409 时自动 MKCOL） |
| `uploadFile(localPath, remoteUrl)` | L518-577 | 上传文件（加密） |
| `uploadFileWithProgress(...)` | L580-637 | 带进度回调的上传 |
| `downloadFile(remoteUrl, localPath)` | L648-668 | 下载文件（解密） |
| `deleteFile(url)` | L671-683 | 删除文件 |
| `listFiles(directoryUrl)` | L686-706 | 列出目录文件 |
| `loadJournalData()` | L727-742 | 读取 data.json |
| `saveJournalData(data)` | L745-769 | 保存 data.json（带云端锁） |
| `clearAllData()` | L864-907 | 清空云端所有数据 |

---

## 4. `lib/services/encryption_service.dart` — AES-256-CBC 加密

| 行号 | 内容 |
|---|---|
| L11 | 文件格式：`[Magic "ENC1" 4字节] + [IV 16字节] + [密文]` |
| L20-30 | 密钥派生：从 `serverUrl|username|token` SHA-256 |
| L52-58 | `encryptText()` |
| L62-78 | `decryptText()` |
| L82-88 | `encryptBytes()` |
| L92-106 | `decryptBytes()` |
| L109-114 | `_hasMagicHeader()` — 自动检测加密/明文 |

---

## 5. `lib/services/local_settings_service.dart` — 本地设置

| 行号 | 字段 |
|---|---|
| L7-18 | SharedPreferences key 常量 |
| L23-48 | `getSettings()` — 读取全部设置 |
| L50-71 | `saveSettings(settings)` — 保存 |

**Settings 字段命名（按 guide.skill）**：
- ❌ `cacheEnabled` → ✅ `syncEnabled`
- ❌ `cacheSyncInterval` → ✅ `syncInterval`

---

## 6. `lib/services/log_service.dart` — 日志

| 行号 | 内容 |
|---|---|
| L6 | `enum LogLevel { info, success, warning, error }` |
| L9-30 | `class AppLog`（含 `formatted` 文本） |
| L33-95 | `class LogService extends ChangeNotifier` |
| L35 | 最多保留 500 条日志 |
| L74-84 | 快捷方法：`info()` / `success()` / `warn()` / `error()` |

---

## 7. `lib/models/post.dart` — 数据模型

| 行号 | 模型 |
|---|---|
| L4-83 | `class Post`（动态/帖子）：id、content、mediaFiles、videoFile、videoThumbnail、tags、createdAt、updatedAt |
| L86-126 | `class SyncMeta`（同步元数据） |
| L129-189 | `class JournalData`（数据集合）：version、lastModified、posts、syncMeta |
| L192-254 | `class WebDavConfig` + `enum AuthMethod`（token/basic） |

---

## 8. `lib/functionality/feed/feed_bloc.dart` — 动态数据 Bloc

| 行号 | 内容 |
|---|---|
| L18-37 | `class FeedBloc extends Bloc<FeedEvent, FeedState>` 构造（注册 11 个事件） |
| L39-53 | setter：`setWebDavService` / `setSyncService` / `setLogService` / `setOnAuthError` |
| L57-73 | `performManualSync()` — 主页"同步"按钮调用 |
| L75-141 | `_onLoad()` — 加载：本地 → 后台推送 → 后台拉取 |
| L143-160 | `_emitLoaded()` |
| L176-292 | `_onCreatePost()` — 创建帖子（含视频封面生成） |
| L294-323 | `_generateVideoThumbnail()` — 第 1 秒关键帧 → 首帧兜底 |
| L363-447 | `_onEditPost()` |
| L449-499 | `_onDeletePost()` |
| L501-589 | `_onSearch` / `_onFilterByTag` / `_onClearFilter` / `_onColumnChanged` / `_onSortChanged` / `_onDateFilter` |
| L591-636 | `_applySort()` / `_applyAllFilters()` |

---

## 9. `lib/functionality/auth/auth_bloc.dart` — 认证

| 行号 | 内容 |
|---|---|
| L12-23 | `class AuthBloc` 构造（AuthCheck/AuthLogin/AuthLogout） |
| L53-92 | `_onCheck()` — 启动自动连接 |
| L94-128 | `_onLogin()` |
| L130-141 | `_onLogout()` |

---

## 10. `lib/functionality/home/app_bloc.dart` — 全局应用 Bloc

| 行号 | 内容 |
|---|---|
| L16-32 | `class AppBloc` |
| L40-109 | `_onInitialize()` — 从 WebDAV 拉用户资料/头像 |
| L111-147 | `_onThemeChanged` / `_onSettingsUpdated` / `_onNavigationChanged` |

---

## 11. `lib/ui/home/home_screen.dart` — 主屏幕（底部导航）

| 行号 | 内容 |
|---|---|
| L10-54 | 3 个 Tab：FeedScreen(首页) / DiscoverScreen(搜索) / ProfileScreen(我的) |
| L33-44 | 底部 `NavigationBar`：首页/搜索/我的 |

---

## 12. `lib/ui/feed/feed_screen.dart` — 首页（动态信息流） ⭐ 核心 UI

### 12.1 `_FeedScreenState`（L19-356）

| 行号 | 内容 |
|---|---|
| L20-25 | `initState` → 触发 `FeedLoadEvent` |
| L27-82 | `build()` — Scaffold + `RefreshIndicator` + `CustomScrollView` |
| L70-81 | **FAB 发布按钮**：`FloatingActionButton.extended`，图标 `Icons.edit_rounded` + 文字"发布" |
| L84-263 | `_buildAppBar()` — `SliverAppBar`（pinned） |
| **L136-240** | **`_SyncButton` 同步按钮**（核心交互） |
| L243-263 | `_showDatePicker()` — 日期范围筛选 |

### 12.2 `_SyncButton`（L359-563）— 同步按钮详细

> 主页顶部工具栏最右侧的圆角矩形按钮（按 guide.skill 第一节）

| 行号 | 内容 |
|---|---|
| L359-380 | `class _SyncButton extends StatefulWidget` + `AnimationController` 旋转动画 |
| L382-405 | `build()` — 显示同步图标 + "同步"/"同步中" 文字 |
| L407-410 | 颜色与图标对应：idle=灰云 / syncing=蓝旋转 / success=绿对勾 / failed=红叉 |
| L426-457 | `build()` 主体：圆角 14 背景容器（`cs.surfaceContainerHighest`） |
| L459-476 | `_onTap()` 根据状态分发 |
| L478-491 | `_triggerSync()` 调用 `feedBloc.performManualSync()` |
| L493-531 | `_showSyncingDialog()` — 显示当前文件名 + 进度条 |
| L533-567 | `_showSuccessSummary()` — 显示最近同步时间 + 上传/下载数 |
| L569-599 | `_showFailureDialog()` — 显示失败原因 + 服务器返回码 |

### 12.3 `_PostCard`（L606-810）— 动态卡片

| 行号 | 内容 |
|---|---|
| L606 | `_PostCard({required post, required state})` |
| L625 | 卡片外边距 `EdgeInsets.symmetric(horizontal: 12, vertical: 8)` |
| L628-632 | 卡片样式：背景 `cs.surface`，圆角 16，边框 `cs.outlineVariant` |
| L640-703 | 顶部：头像（`CircleAvatar` 半径 20）+ 昵称 + 时间 |
| L705-722 | 中部：文字内容（`#标签` 高亮） |
| L724-726 | 下部：媒体网格（`_MediaGrid`） |
| L748-789 | 标签 chips（圆角 8，点击触发 `FeedFilterByTagEvent`） |
| L791-807 | 底部：视频标识 |
| L812-848 | `_buildContentSpans()` — 提取 `#标签` 高亮显示 |
| L850-852 | `_fmtTime()` — 时间格式化 |

### 12.4 `_MediaGrid`（L857-1029）— 媒体网格

| 行号 | 内容 |
|---|---|
| L866-878 | 计算网格（单图/单视频/多图） |
| L882-906 | 单个媒体（最大 70% 屏宽，圆角 16） |
| L908-945 | 多个媒体（2 列或 3 列网格，圆角 16） |
| L947-952 | 视频位置第一帧（封面） |
| L965-976 | "9+" 蒙层 |
| L987-1005 | `_buildVideoOnlyCard()` — 单视频卡片 |
| L1007-1016 | `_buildMediaBox()` — 通用容器（圆角 16） |
| L1018-1029 | `_buildImage()` — 通过 `MediaUtils.buildImage` 加载 |

---

## 13. `lib/ui/post/post_detail_screen.dart` — 详情页 ⭐ 核心 UI

### 13.1 `PostDetailScreen`（L18-180）

| 行号 | 内容 |
|---|---|
| L34-57 | AppBar：标题"详情" + 标签/编辑/删除 三个 IconButton（右上角菜单） |
| L73-110 | 文字内容（`_buildRichContent`） |
| L71 | `_MediaCarousel`（图片轮播） |
| L74 | `_VideoPlayerCard`（视频卡片） |
| L82-108 | 时间 pill（圆角 20） + 标签 chips（圆角 14） |

### 13.2 详情页交互（标签管理，按 guide.skill 第七节）

| 行号 | 内容 |
|---|---|
| L129-181 | `_showTagsDialog()` — 标签管理弹窗，文本输入空格分隔 |

### 13.3 `_VideoPlayerCard`（L188-310）— 视频卡片

| 行号 | 内容 |
|---|---|
| L216-260 | `_prepareVideo()` — 加载本地视频文件，不存在则下载解密 |
| L262-291 | `_buildThumbnail()` — 显示视频封面（缩略图/占位） |
| L293-330 | `build()` — 16:9 卡片（圆角 16） |

### 13.4 `_VideoPlayerScreen`（L317-460）— 全屏视频播放器

> 按 guide.skill 第六节：封面先行 + 横屏按钮 + 底部控制栏

| 行号 | 内容 |
|---|---|
| L334-340 | 媒体播放器初始化（media_kit） |
| L342-347 | 销毁时恢复 `SystemUiMode.edgeToEdge`（不强制横屏） |
| L349-358 | `_togglePlay()` — 首次播放 |
| L364-372 | `_fmt()` — 时间格式化 mm:ss |
| L376-446 | `build()` — 视频控制界面 |
| L391-395 | 顶部：返回 + 信息 + 更多 |
| L397-422 | 中央播放按钮（首次） |
| L424-457 | 底部控制栏：进度条 + 播放/暂停 + 时间 + 音量 + 横屏按钮 |

### 13.5 `_MediaCarousel`（L462-555）— 图片轮播

| 行号 | 内容 |
|---|---|
| L467 | PageController |
| L482-538 | `build()` — 计算可用高度 + PageView 切换 |
| L551-573 | `_openGallery()` — 进入全屏画廊 |

### 13.6 `_GalleryScreen`（L563-780）— 全屏图片查看器

> 按 guide.skill 第五节：返回 + 信息 + 更多 + 双击缩放 + 底部计数 + 功能菜单

| 行号 | 内容 |
|---|---|
| L576-582 | 状态：当前索引 + ImageProvider 缓存 |
| L584-595 | 预加载首张 + 左右各一张 |
| L597-660 | `_loadImage()` — 本地优先 → 下载解密 → 缓存 |
| L666-748 | `build()` — PageView + ExtendedImage（手势缩放） |
| L675-696 | 顶部：返回 + 信息 + 更多 |
| L698-720 | 底部 3/12 计数 |
| L750-768 | `_showImageInfo()` — 图片信息弹窗（圆角 20） |
| L774-810 | `_showMoreMenu()` — 功能菜单（保存/分享/标签/EXIF/删除） |
| L812-826 | `_menuTile()` — 通用菜单项（圆角 14） |

---

## 14. `lib/ui/post/create_post_screen.dart` — 发布/编辑页

### 14.1 `CreatePostScreen`（L11-619）

| 行号 | 内容 |
|---|---|
| L14-21 | 构造（支持 `editPost` 进入编辑模式） |
| L33-54 | `_CreatePostScreenState` 初始化（预填编辑内容） |
| L56-78 | `_pickImages()` / `_pickVideo()` |
| L82-90 | `_extractTagsFromContent()` — 从 # 提取标签 |
| L107-138 | `_publish()` — 触发 `FeedCreatePostEvent` / `FeedEditPostEvent` |
| L144-511 | `build()` — Scaffold + 内容输入 + 媒体网格 + 标签 |
| L159-166 | AppBar：标题"发布动态"/"编辑动态" + 右上角保存按钮（圆角 14） |
| L211-222 | 文字输入（高度 5-8 行） |
| L226-233 | 已有图片（编辑模式） |
| L246-294 | 视频预览 |
| L337-399 | 添加媒体按钮（图片/视频，圆角 12） |
| L401-427 | 标签输入提示 + 已识别标签 chips |
| L433-505 | 上传进度遮罩（圆角 20） |

### 14.2 `_buildExistingMediaGrid`（L514-570）— 编辑模式远程图片网格

| 行号 | 内容 |
|---|---|
| L519-526 | 3 列网格 |
| L534-545 | 通过 `MediaUtils.buildImage` 显示远程图片 |
| L548-565 | 删除按钮 |

### 14.3 `_buildImageGrid`（L572-618）— 新增本地图片网格

| 行号 | 内容 |
|---|---|
| L580-586 | 3 列网格（`Image.file`） |
| L599-613 | 删除按钮 |

---

## 15. `lib/ui/discover/discover_screen.dart` — 搜索页

### 15.1 `DiscoverScreen`（L11-247）

| 行号 | 内容 |
|---|---|
| L18-39 | `_DiscoverScreenState` — 300ms 防抖搜索 |
| L41-76 | `_onSearchChanged` / `_doSearch` / `_clearSearch` / `_filterPosts` |
| L78-173 | `build()` — Scaffold + 搜索栏 + 热门标签 + 结果列表 |
| L86-112 | 搜索栏（圆角 14） |
| L175-237 | `_buildHotTags()` — 横向标签滚动条 |
| L239-247 | `_buildPostList()` — 搜索结果列表 |

### 15.2 `_SearchResultCard`（L251-353）

| 行号 | 内容 |
|---|---|
| L267-272 | 卡片圆角 16 |
| L284-300 | 缩略图（72x72，圆角 12） |
| L302-324 | 内容（最多 2 行） |
| L329-344 | 标签 + 时间 + 媒体数 |

---

## 16. `lib/ui/profile/profile_screen.dart` — 我的页面

### 16.1 `_ProfileScreenState`（L19-509）

| 行号 | 内容 |
|---|---|
| L21-26 | `initState` — 订阅 `sync.onSyncStateChanged` |
| L29-219 | `build()` — CustomScrollView（个人信息 + 数据管理 + 设置 + 危险操作） |
| L38-99 | AppBar + 个人信息（点击编辑） |
| L106-150 | **数据管理分区**（按 guide.skill：本地/云端/同步/快照） |
| L155-208 | 通用设置（查看日志/复制日志/主题） |
| L213-252 | 危险操作（清除云端/退出登录） |
| L261-400 | `_editProfile()` — 编辑昵称/头像弹窗（圆角 20） |
| L402-448 | `_confirmClearCloud()` — 清除确认（圆角 20） |
| L450-467 | `_confirmLogout()` — 退出登录确认 |

### 16.2 `_LocalDataTile`（L515-617）

| 行号 | 内容 |
|---|---|
| L520 | 加载本地数据大小 |
| L527-538 | `_formatSize()` — B/KB/MB/GB |
| L544-548 | ListTile（图标 `Icons.folder_rounded`） |
| L554-616 | 详情弹窗（清除按钮） |

### 16.3 `_CloudDataTile`（L621-）

| 行号 | 内容 |
|---|---|
| 显示服务器地址 + 存储路径（只读） |

### 16.4 `_SyncTile`

| 行号 | 内容 |
|---|---|
| 显示同步开关 + 状态文字（同步中 N/M / 已同步 / 同步出错 / 已开启） |
| Switch 切换会触发 `AppSettingsUpdatedEvent` 并调用 `performManualSync()` |

### 16.5 `_SnapshotTile`

| 行号 | 内容 |
|---|---|
| `listSnapshots()` 列出快照 |
| 右上角 `+` 按钮：手动创建快照 |
| 每条快照右侧"恢复"按钮：调用 `restoreSnapshot()` |

### 16.6 `_ThemeTile` / `_SettingTile`

主题切换 / 通用设置项（带 chevron）

---

## 17. `lib/ui/log/log_viewer_screen.dart` — 日志查看

| 行号 | 内容 |
|---|---|
| L13-17 | 多选模式状态 |
| L19-103 | AppBar（标题显示数量/已选数） + 多选/复制/清空 按钮 |
| L87-101 | 列表（`_LogTile`） |
| L105-117 | 点击/长按逻辑 |
| L141-157 | 复制选中 |
| L199-275 | 单条详情弹窗（`DraggableScrollableSheet`） |
| L286-399 | `_LogTile` 渲染 |
| L401-437 | `_LevelChip`（INFO/OK/WARN/ERR） |

---

## 18. `lib/utils/media_utils.dart` — 媒体加载工具

| 行号 | 内容 |
|---|---|
| L11 | `class MediaUtils` |
| L13 | `static SyncService? syncService` — 全局绑定 |
| L15-27 | `buildMediaUrl(state, fileName)` — 构造云端 URL（Web 端注入 auth 参数） |
| L29-41 | `getFirstImageUrl()` |
| L43-106 | `buildImage()` — 本地优先 → 远程加密加载 |
| L108-160 | `buildFullWidthImage()` — 详情页全宽 |
| L208-324 | `_LoadLocalImage` — 从本地读字节渲染 |
| L327-432 | `_EncryptedCachedImage` — 加密网络图片 |

---

## 19. `lib/utils/error_helper.dart` — 错误中文化

| 行号 | 内容 |
|---|---|
| L6-42 | `friendly(e, {prefix})` — 把任意异常转为中文 |
| L45-51 | `isAuthError(e)` — 判断是否 401/403 |

匹配规则：401/403/404/407/500/502/503/504/timeout/SocketException/HandshakeException/Connection refused

---

## 20. 圆角速查（按 guide.skill）

| 用途 | 数值 | 代码位置 |
|---|---|---|
| 卡片 | 16dp | `cardTheme` (main.dart L100)、`_PostCard` (feed_screen.dart L629) |
| 按钮 | 14dp | `filledButtonTheme` (main.dart L134)、`_SyncButton` (feed_screen.dart L426) |
| 弹窗 | 20dp | `dialogTheme` (main.dart L116)、`AlertDialog` |
| 输入框 | 14dp | `inputDecorationTheme` (main.dart L130) |
| 缩略图 | 16dp | `_MediaGrid` (feed_screen.dart L1011) |

---

## 21. 状态机速查（按 guide.skill）

### 21.1 数据同步状态（SyncStatus）

```
idle ──触发同步──> syncing ──成功──> success
                            └─失败──> failed
```

| 状态 | 图标 | 颜色 | 触发动作 |
|---|---|---|---|
| `idle` | `cloud_outlined` | 灰 | 点击 → 开始同步 |
| `syncing` | `sync_rounded`（旋转） | 蓝 | 点击 → 显示进度弹窗 |
| `success` | `cloud_done_rounded` | 绿 | 点击 → 显示最近同步摘要 |
| `failed` | `cloud_off_rounded` | 红 | 点击 → 显示失败原因 |

### 21.2 FeedBloc 状态

```
initial → loading → loaded
                  ├→ publishing → loaded
                  ├→ editing → loaded
                  └→ error
```

### 21.3 AuthBloc 状态

```
initial → checking → authenticated / local / error
                            → unauthenticated
                            → loggingIn → authenticated / error
```

---

## 22. 颜色与样式速查

### 22.1 Material 3 主题

| 主题键 | 用途 |
|---|---|
| `cs.surface` | 卡片背景 |
| `cs.surfaceContainerHighest` | 输入框/进度条背景 |
| `cs.primary` | 主操作色 |
| `cs.onSurface` | 主要文字 |
| `cs.onSurfaceVariant` | 次要文字 |
| `cs.outlineVariant` | 边框线 |
| `cs.errorContainer` | 错误背景 |
| `cs.primaryContainer` | 标签背景 |

### 22.2 常用数值

| 名称 | 数值 |
|---|---|
| `Icon size 16` | 小按钮内 |
| `Icon size 22-24` | AppBar |
| `Icon size 28-32` | 视频控制 |
| `Icon size 40-56` | 大操作按钮 |
| `Avatar radius 20` | 小头像（动态卡片） |
| `Avatar radius 40` | 大头像（我的页面） |
| `Spacing 8` | 元素间小间距 |
| `Spacing 12-16` | 卡片内边距 |
| `Spacing 24` | 区块间距 |
| `BorderRadius 12` | 标签 chip |
| `BorderRadius 14` | 输入框/按钮 |
| `BorderRadius 16` | 卡片/媒体 |
| `BorderRadius 20` | 弹窗/BottomSheet |

---

## 23. 关键文件路径速查

```
lib/
├── main.dart                                     ← 应用入口
├── models/
│   ├── post.dart                                  ← Post/JournalData/WebDavConfig
│   └── settings.dart                              ← AppSettings
├── services/
│   ├── sync_service.dart                          ← 【核心】数据同步
│   ├── webdav_service.dart                        ← WebDAV 客户端
│   ├── encryption_service.dart                    ← AES-256 加密
│   ├── local_settings_service.dart                ← SharedPreferences
│   └── log_service.dart                           ← 日志（500 条）
├── functionality/
│   ├── auth/auth_bloc.dart                        ← WebDAV 登录
│   ├── home/app_bloc.dart                         ← 全局主题/设置
│   └── feed/feed_bloc.dart                        ← 【核心】动态数据
├── ui/
│   ├── home/home_screen.dart                      ← 底部导航（3 Tab）
│   ├── feed/feed_screen.dart                      ← 【核心】首页 + 同步按钮
│   ├── post/
│   │   ├── post_detail_screen.dart                ← 【核心】详情 + 查看器
│   │   └── create_post_screen.dart                ← 发布/编辑
│   ├── discover/discover_screen.dart              ← 搜索
│   ├── profile/profile_screen.dart                ← 【核心】我的 + 数据管理
│   ├── auth/login_screen.dart                     ← WebDAV 登录
│   └── log/log_viewer_screen.dart                 ← 日志查看
└── utils/
    ├── media_utils.dart                           ← 图片加载
    └── error_helper.dart                          ← 错误中文化
```

---

## 24. 如何修改常见内容

### 24.1 修改同步按钮样式 / 状态

打开 `lib/ui/feed/feed_screen.dart` → `_SyncButton` 类（L359 附近）

### 24.2 修改圆角

打开 `lib/main.dart` → `_buildLightTheme()` / `_buildDarkTheme()`

### 24.3 修改首页卡片布局

打开 `lib/ui/feed/feed_screen.dart` → `_PostCard` 类（L606 附近）

### 24.4 修改图片/视频查看器

打开 `lib/ui/post/post_detail_screen.dart` → `_GalleryScreen` / `_VideoPlayerScreen`

### 24.5 修改数据同步逻辑

打开 `lib/services/sync_service.dart` → `SyncService` 类

### 24.6 修改"我的"页面数据管理

打开 `lib/ui/profile/profile_screen.dart` → `_LocalDataTile` / `_CloudDataTile` / `_SyncTile` / `_SnapshotTile`

### 24.7 添加新设置项

1. 在 `lib/models/settings.dart` 添加字段 + `copyWith`
2. 在 `lib/services/local_settings_service.dart` 添加 key
3. 在 `lib/ui/profile/profile_screen.dart` 添加 ListTile

### 24.8 修改 WebDAV 连接逻辑

打开 `lib/services/webdav_service.dart` → `WebDavService`

---

## 25. 调试技巧

| 问题 | 查看 |
|---|---|
| 同步不工作 | `lib/services/sync_service.dart` 的 `_setStatus()` |
| 数据不显示 | `FeedBloc._onLoad()` 是否成功调用 `loadLocalData()` |
| 图片加载失败 | `lib/utils/media_utils.dart` 的 `_buildNetworkImage()` |
| 视频无法播放 | `media_kit` 初始化（`lib/main.dart` L18） |
| 主题不生效 | `lib/main.dart` 的 `MaterialApp.theme` / `darkTheme` |
| 圆角不对 | 全文搜索 `BorderRadius.circular` |

---

## 26. 常见任务代码片段

### 26.1 触发手动同步

```dart
final ok = await context.read<FeedBloc>().performManualSync();
if (ok) {
  // 同步成功
}
```

### 26.2 创建数据快照

```dart
final sync = context.read<SyncService>();
final data = await sync.loadLocalData();
if (data != null) {
  await sync.createSnapshot(data);
}
```

### 26.3 列出快照

```dart
final sync = context.read<SyncService>();
final snapshots = await sync.listSnapshots();
// snapshots: List<SnapshotInfo>
```

### 26.4 恢复快照

```dart
final sync = context.read
<SyncService>();
final data = await sync.restoreSnapshot(snapshotPath);
if (data != null) {
  // 恢复成功
}
```

### 26.5 在 UI 中读取 SyncService

```dart
// 监听
final sync = context.watch<SyncService>();

// 读取一次
final sync = context.read<SyncService>();

// 判断状态
if (sync.syncStatus == SyncStatus.syncing) { ... }
```

### 26.6 显示加载状态（动态页）

```dart
BlocConsumer<FeedBloc, FeedState>(
  listenWhen: (p, c) => p.uploadProgress != c.uploadProgress,
  listener: (context, state) {
    if (state.uploadProgress >= 1.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.uploadStatusText ?? '完成')),
      );
    }
  },
  builder: (context, state) {
    return state.status == FeedStatus.loading
      ? const Center(child: CircularProgressIndicator())
      : ListView(...);
  },
);
```

### 26.7 弹出 BottomSheet

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (ctx) => Container(
    decoration: BoxDecoration(
      color: Theme.of(ctx).colorScheme.surface,
      borderRadius: BorderRadius.circular(20), // 圆角 20
    ),
    child: ...
  ),
);
```

---

## 27. UI 布局坐标说明

### 27.1 首页（FeedScreen）

```
┌─────────────────────────────────────┐
│ [☰] [生活动态 N]      [同步] [≡] [📅] │  AppBar
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ [头像] [昵称]                   │ │  PostCard
│ │       [时间]                     │ │  (圆角 16)
│ │ ─────────────────────────────── │ │
│ │ 文字内容 #标签#高亮              │ │
│ │ ┌─────┬─────┬─────┐             │ │
│ │ │图片 │图片 │图片 │  _MediaGrid │ │
│ │ └─────┴─────┴─────┘             │ │
│ │ [#标签] [#标签]                  │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│                  [📝 发布]  ← FAB  │
└─────────────────────────────────────┘
```

### 27.2 详情页（PostDetailScreen）

```
┌─────────────────────────────────────┐
│ ← [详情]              [🏷️] [✏️] [🗑️] │  AppBar
├─────────────────────────────────────┤
│ 文字内容（可选择）                  │
│ ┌─────────────────────────────────┐ │
│ │                                 │ │
│ │       图片轮播                  │ │  _MediaCarousel
│ │       (可左右滑动)              │ │
│ │                                 │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ ┌───────────────────────────┐   │ │
│ │ │       视频卡片 16:9         │ │  _VideoPlayerCard
│ │ │       [▶ 点击播放]         │   │
│ │ └───────────────────────────┘   │ │
│ └─────────────────────────────────┘ │
│ [🕒 时间] [#标签] [#标签]            │
└─────────────────────────────────────┘
```

### 27.3 我的页面（ProfileScreen）

```
┌─────────────────────────────────────┐
│ 我的                                │  AppBar
├─────────────────────────────────────┤
│        [头像 80x80]                 │
│         昵称                        │  个人信息
│      点击编辑个人资料               │
├─────────────────────────────────────┤
│ 数据管理                            │  分组标题
│ ┌─────────────────────────────────┐ │
│ │ 📁 本地数据 N 个文件 X MB      │ │
│ ├─────────────────────────────────┤ │
│ │ ☁️ 云端数据 / 服务器地址        │ │  数据管理
│ ├─────────────────────────────────┤ │  (4 项)
│ │ 🔄 数据同步 [开关]              │ │
│ ├─────────────────────────────────┤ │
│ │ 📚 数据快照 (思源笔记风格)       │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ 设置                                │
│ ┌─────────────────────────────────┐ │
│ │ 📄 查看日志 N 条                │ │
│ ├─────────────────────────────────┤ │
│ │ 📋 复制日志                     │ │
│ ├─────────────────────────────────┤ │
│ │ 🎨 主题模式                     │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ 🗑️ 清除云端数据                │ │  危险操作
│ ├─────────────────────────────────┤ │
│ │ 🚪 退出登录                     │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### 27.4 全屏图片查看器（_GalleryScreen）

```
┌─────────────────────────────────────┐
│ ← (半透明黑)              [ℹ️] [⋮] │  顶部按钮
│                                     │
│                                     │
│                                     │
│                                     │
│         图像区域（黑色背景）        │  PageView
│         支持双击/双指缩放          │
│         支持左右滑动                │
│                                     │
│                                     │
│                                     │
│                                     │
│              [3 / 12]               │  底部计数
└─────────────────────────────────────┘

点击 [⋮] 弹出底部菜单（圆角 20）：
┌───────────────────────┐
│         ━━━            │  拖动条
│ 保存到相册           │
│ 分享                 │
│ 添加标签             │
│ 查看 EXIF            │
│ 删除                 │
└───────────────────────┘
```

### 27.5 全屏视频播放器（_VideoPlayerScreen）

```
┌─────────────────────────────────────┐
│ ← (半透明黑)        [ℹ️] [⋮]         │  顶部
│                                     │
│                                     │
│                                     │
│         视频区域（黑色背景）        │  16:9
│         不强制横屏                  │
│         首次显示 ▶ 按钮            │
│                                     │
│                                     │
│                                     │
│ ━━━━━━━━━●━━━━━━━━━━━━━━━━          │  进度条
│ ▶ 00:23    🔊  [横屏]   01:45       │  底部控制
└─────────────────────────────────────┘

横屏按钮：调用 SystemChrome.setPreferredOrientations
            让用户主动进入横屏（不强制）
```

### 27.6 同步按钮（_SyncButton）

```
位于首页 AppBar 最右侧（菜单按钮之前）

[ ☁️ 同步 ]    ← idle 灰色
[ 🔄 同步中 ]  ← syncing 蓝色旋转
[ ☁️✓ 同步 ]  ← success 绿色
[ ☁️✕ 同步 ]  ← failed 红色
```

点击弹窗：
- syncing → 进度弹窗（圆角 20）
- success → 最近同步摘要（时间 + 上传 N 个 + 下载 M 个）
- failed → 失败原因 + 服务器返回码
- idle → 直接触发 `performManualSync()`

---

## 28. 命名约定速查

| 类型 | 命名 | 示例 |
|---|---|---|
| Bloc | `XxxBloc` | `FeedBloc`、`AuthBloc` |
| Event | `XxxEvent` | `FeedLoadEvent`、`AuthLoginEvent` |
| State | `XxxState` | `FeedState`、`AuthState` |
| 枚举 | `XxxEnum/Status/Mode` | `SyncStatus`、`FeedSortMode` |
| Service | `XxxService` | `SyncService`、`WebDavService` |
| Widget | `XxxScreen` / `_Xxx` | `FeedScreen` / `_PostCard` |
| 私有类 | 下划线开头 | `_SyncButton`、`_LocalDataTile` |
| 文件 | snake_case | `sync_service.dart` |

---

## 29. 修改指南：常见修改场景

### 29.1 添加新的同步状态

1. 在 `lib/services/sync_service.dart` 的 `enum SyncStatus` 添加成员
2. 在 `SyncService` 添加对应状态字段（如需）
3. 在 `lib/ui/feed/feed_screen.dart` 的 `_SyncButton` 添加图标/颜色映射
4. 在 `_showSyncingDialog` / `_showSuccessSummary` / `_showFailureDialog` 添加新分支
5. 在 `lib/ui/profile/profile_screen.dart` 的 `_SyncTile` 添加状态文字

### 29.2 添加新的底部导航 Tab

1. 在 `lib/ui/home/home_screen.dart` 的 `IndexedStack.children` 和 `NavigationBar.destinations` 各加一项
2. 创建新页面 `lib/ui/xxx/xxx_screen.dart`
3. 在 `lib/functionality/` 创建对应 Bloc（如需）

### 29.3 修改发布流程

- **添加媒体类型**：修改 `lib/functionality/feed/feed_bloc.dart` 的 `_onCreatePost`，新增 `_saveXxxFileLocally` 方法
- **修改发布字段**：修改 `lib/models/post.dart` 的 `Post` 类，同步更新 `FeedEvent`/`FeedState`
- **UI 调整**：修改 `lib/ui/post/create_post_screen.dart`

### 29.4 添加新数据字段到设置

1. `lib/models/settings.dart`：添加字段 + `copyWith`
2. `lib/services/local_settings_service.dart`：添加 SharedPreferences key + 读写
3. `lib/ui/profile/profile_screen.dart`：添加 ListTile + 处理 onChanged

### 29.5 添加新的媒体类型支持

1. 在 `Post.mediaFiles` / `Post.videoFile` 旁边添加新字段
2. 在 `_MediaGrid` 添加对应渲染
3. 在 `_GalleryScreen` / `_VideoPlayerScreen` 添加对应查看器
4. 在 `MediaUtils` 添加加载工具

### 29.6 修改 WebDAV 协议细节

- `lib/services/webdav_service.dart` 的 `_dio.options.validateStatus` 控制哪些 HTTP 码不抛错
- `setRawDataEnabled` 控制是否上传 raw/ 明文副本
- 锁超时 `_lockTimeoutSeconds = 60`（秒）

### 29.7 修改加密方案

- `lib/services/encryption_service.dart` 的 `_initKey` 控制密钥派生
- `_magicHeader = "ENC1"`（4 字节）控制加密文件识别
- 解密失败时会尝试明文读取（向后兼容）

---

## 30. 故障排查清单

| 现象 | 排查步骤 |
|---|---|
| 应用启动白屏 | 1. `lib/main.dart` L13 `main()` 是否报错<br>2. `MediaKit.ensureInitialized()` 是否成功<br>3. WebDAV 配置是否损坏 |
| 登录失败 | 1. `lib/services/webdav_service.dart` `testConnectionDetailed`<br>2. SSL 证书（Android）<br>3. 服务器返回码 |
| 同步卡住 | 1. `lib/services/sync_service.dart` `syncStatus` 当前状态<br>2. `_currentFileName` 是否更新<br>3. 后台定时器是否触发 |
| 图片 401 | 1. `webDavService.imageHeaders` 是否设置<br>2. 加密模式下 `EncryptionService` 密钥是否匹配 |
| 视频不能播放 | 1. `media_kit` 初始化<br>2. `_localPath` 是否下载完成<br>3. 视频编码格式 |
| 圆角不生效 | 1. 是否使用 `ThemeData` 的全局圆角<br>2. 是否被 Container 局部覆盖 |
| 主题异常 | 1. `MaterialApp.themeMode`<br>2. `DynamicColorBuilder` 取值<br>3. `_buildLightTheme`/`_buildDarkTheme` |

---

## 31. 平台差异速查

| 平台 | 视频播放 | 视频缩略图 | 文件路径 |
|---|---|---|---|
| Android | media_kit (mpv) | VideoThumbnail | `getApplicationDocumentsDirectory()` |
| iOS | media_kit (mpv) | VideoThumbnail | `getApplicationDocumentsDirectory()` |
| Linux | media_kit (libmpv) | 跳过 | `getApplicationDocumentsDirectory()` |
| Windows | media_kit (libmpv) | 跳过 | `getApplicationDocumentsDirectory()` |
| macOS | media_kit (mpv) | VideoThumbnail | `getApplicationDocumentsDirectory()` |
| Web | media_kit Video (HTML5) | VideoThumbnail (canvas) | IndexedDB (浏览器侧) |

> Linux/Windows 在 `feed_bloc.dart` `_onCreatePost` 中跳过视频封面生成（避免 Platform 异常）。

---

## 32. 关键流程图

### 32.1 应用启动流程

```
main()
  ↓
WidgetsFlutterBinding.ensureInitialized()
  ↓
MediaKit.ensureInitialized()
  ↓
runApp(LifeApp)
  ↓
MultiBlocProvider 注入
  ↓
AuthBloc: AuthCheckEvent
  ├─ 无 WebDAV 配置 → AuthStatus.local
  └─ 有配置 → testConnection
       ├─ 成功 → AuthStatus.authenticated
       └─ 失败 → AuthStatus.local（保留配置）
  ↓
AppBloc: AppInitializeEvent → 加载 settings + 用户资料
  ↓
SyncService.init() → 扫描本地媒体
  ↓
startBackgroundSync() → 启动定时清理
  ↓
构建 MaterialApp
  ↓
HomeScreen（已认证）/ LoginScreen（未认证）
```

### 32.2 发布动态流程

```
CreatePostScreen._publish()
  ↓
FeedBloc: FeedCreatePostEvent
  ↓
_onCreatePost()
  ├─ 1. 保存图片到 local_data/media/
  ├─ 2. 保存视频到 local_data/media/
  ├─ 3. 生成视频封面（第1秒关键帧 → 首帧兜底）
  ├─ 4. 保存音频
  ├─ 5. 保存 data.json 到 local_data/
  ├─ 6. markPendingSync(true)
  └─ 7. emit FeedStatus.loaded
  ↓
SyncService.pendingSync = true
  ↓
后台推送（或用户点击主页"同步"按钮手动触发）
  ↓
pushToCloud()
  ├─ 上传本地所有媒体到 WebDAV
  ├─ 写入 data.json 到 WebDAV（带云端锁）
  └─ createSnapshot()
```

### 32.3 拉取远端流程

```
FeedBloc._onLoad()
  ↓
loadLocalData() → 本地 data.json
  ↓
（后台）loadJournalData() → 远端 data.json
  ↓
pullFromCloud()
  ├─ 远程为基准 + 本地独有 = merged
  ├─ saveLocalData(merged)
  └─ createSnapshot(merged)
  ↓
add(FeedRefreshEvent) → 触发 UI 刷新
```

---

## 33. 相关文档

- [docs/guide.skill](../guide.skill) — 设计规范原始文档
- [README.md](../README.md) — 项目介绍
- [docs/APP_DESIGN.md](../docs/APP_DESIGN.md) — 设计文档
- [docs/WEBDAV_ARCHITECTURE.md](../docs/WEBDAV_ARCHITECTURE.md) — WebDAV 架构
- [docs/WEB_SETUP.md](../docs/WEB_SETUP.md) — Web 端配置
- [docs/BUILD_GUIDE.md](../docs/BUILD_GUIDE.md) — 编译指南

---

**文档版本**：v1.0
**最后更新**：基于 guide.skill 重构后
**维护建议**：每次修改 UI/服务时同步更新本文档对应章节的行号

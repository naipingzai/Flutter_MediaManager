# 本地编译指南

本文档介绍如何在本地环境编译 Flutter Media Manager 应用。

---

## 环境要求

| 工具 | 版本要求 | 说明 |
|------|---------|------|
| Flutter SDK | 3.27.0+ | https://flutter.dev |
| Dart SDK | 3.5.0+ | 随 Flutter 安装 |
| Android Studio | 最新版 | Android 编译需要 |
| Xcode | 15+ | iOS 编译需要（仅 macOS） |
| JDK | 17 | Android 编译需要 |

### 安装 Flutter

```bash
# macOS / Linux
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# 或使用 FVM（推荐，可管理多个版本）
dart pub global activate fvm
fvm install 3.27.0
fvm use 3.27.0
```

---

## Android 编译

### 1. 获取依赖

```bash
flutter pub get
```

### 2. Debug 运行

```bash
flutter run
```

### 3. 构建 Release APK

```bash
flutter build apk --release
```

产物位置：`build/app/outputs/flutter-apk/app-release.apk`

### 4. 构建 App Bundle（用于上架 Google Play）

```bash
flutter build appbundle --release
```

产物位置：`build/app/outputs/bundle/release/app-release.aab`

### 5. 安装到设备

```bash
# USB 连接设备后
flutter install

# 或直接用 adb
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## iOS 编译

> ⚠️ iOS 编译**必须在 macOS 上进行**，需要安装 Xcode。

### 1. 获取依赖

```bash
flutter pub get
cd ios
pod install
cd ..
```

### 2. 模拟器运行

```bash
# 列出可用模拟器
xcrun simctl list devices

# 启动模拟器（例如 iPhone 16）
open -a Simulator

# 运行
flutter run
```

### 3. 构建模拟器版本（无需签名）

```bash
flutter build ios --simulator
```

产物位置：`build/ios/iphonesimulator/Runner.app`

安装到模拟器：
```bash
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
```

### 4. 构建真机版本（需要签名）

#### 方式 A：免费 Apple ID 签名（7天有效期）

1. 打开 Xcode → Settings → Accounts → 添加你的 Apple ID
2. 打开项目：
   ```bash
   open ios/Runner.xcworkspace
   ```
3. 选择 Runner → Signing & Capabilities：
   - Team：选择你的个人团队
   - Bundle Identifier：改为唯一值，如 `com.yourname.fluttermediamanager`
4. 连接 iPhone，选择你的设备
5. 构建并运行：
   ```bash
   flutter run --release
   ```

> ⚠️ 免费签名限制：
> - 7天后需要重新签名
> - 同一 Apple ID 最多签名 3 个 App
> - 只能安装到已注册的设备（最多 3 台）
> - 无法上架 App Store

#### 方式 B：付费开发者账号（$99/年，推荐）

1. 注册 Apple Developer Program
2. 在 Apple Developer Portal 创建 App ID、Provisioning Profile
3. Xcode 中配置签名
4. 构建 IPA：
   ```bash
   flutter build ipa --release
   ```
5. 产物位置：`build/ios/ipa/flutter_media_manager.ipa`

---

## 自动化构建（CI/CD）

项目使用 GitHub Actions 进行自动构建：

- **Android**：推送到 main/master 自动构建 APK
- **iOS**：推送到 main/master 自动构建模拟器版本（zip）

### 下载构建产物

1. 打开 GitHub 仓库页面
2. 点击 **Actions** 标签
3. 选择对应的 workflow run
4. 页面底部 **Artifacts** 区域下载：
   - `apk` → Android APK
   - `ios-simulator-app` → iOS 模拟器 zip

---

## 常见问题

### Q: flutter pub get 报错 SDK 版本不匹配
A: 确保 Flutter SDK 版本 ≥ 3.27.0，运行 `flutter --version` 检查。

### Q: Android 编译找不到 JDK
A: 确保安装了 JDK 17，设置 `JAVA_HOME` 环境变量。

### Q: iOS 编译报 CocoaPods 错误
A: 运行：
```bash
cd ios
pod deintegrate
pod install
cd ..
```

### Q: iOS 编译报签名错误
A: 确保在 Xcode 中配置了有效的签名团队（参考上方 iOS 真机编译部分）。

### Q: 如何清理构建缓存
A: 运行：
```bash
flutter clean
flutter pub get

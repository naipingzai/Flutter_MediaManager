<div align="center">

## Flutter MediaView

作者：naipingzai · 包名：`com.naipingzai.flutter_media_view`

一个基于 Flutter 的跨平台媒体管理与相册应用。

</div>

## 简介

Flutter MediaView 是一个可视化的媒体管理与元数据浏览应用，目标是覆盖 Android、iOS、Linux、Windows、macOS 等多个平台。应用可将系统相册/文件中的图片与视频导入到应用私有库中统一管理，并支持浏览、检索与元数据查看。

本工程基于 [Aves Gallery](https://github.com/deckerst/aves) 二次开发与重构。

## 功能

- 从系统相册 / 文件选择器导入图片与视频，导入过程实时显示进度
- 以相册、日期等方式浏览与管理媒体
- 支持常见图片与视频格式
- 元数据查看与检索

## 目录结构

采用按功能模块划分的结构组织 `lib/` 目录（详见各功能模块）。

## 构建

应用包含多个 flavor（`izzy` / `play` / `libre`）。默认入口为 `lib/main.dart`（对应 `izzy`）。

安装依赖后构建 Android APK：

```
flutter build apk --flavor izzy --release
```

> 若要使用正式签名，请在 `android/key.properties` 中配置签名密钥。

## 许可

基于 Aves Gallery 二次开发，遵循其原始开源许可（见 [LICENSE](LICENSE)）。

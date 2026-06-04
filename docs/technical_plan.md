# ReadFlow MVP Technical Plan

## 技术方案

ReadFlow MVP 使用 Flutter + Riverpod + SQLite。数据库访问先采用 `sqflite` 与 `sqflite_common_ffi`，避免第一版引入代码生成；后续如果同步、复杂查询和迁移变多，可以平滑迁移到 drift。

网络层使用 `dio` 并设置连接、发送和接收超时。Feed 解析用 `xml` 自行封装，兼容 RSS 2.0、Atom 和常见 RDF。正文摘要处理使用 `html`，详情渲染使用 `flutter_html`。OPML 使用 XML 解析和 `file_picker` 导入导出。

本地数据按用户要求拆为：

- `feeds`
- `entries`
- `categories`
- `app_settings`

刷新策略为启动后刷新一次，应用打开时按设置周期刷新。Android 使用 `workmanager` 注册后台周期任务，频率受 Android 系统限制，最小为 15 分钟；Windows 端先在应用打开时按设置定时刷新。

## 目录结构

```text
lib/
  main.dart
  app.dart
  core/
    database/
    models/
    network/
    theme/
    utils/
  features/
    categories/
      data/
      presentation/
    entries/
      data/
      presentation/
    feeds/
      data/
      presentation/
    movie/
      presentation/
    novel/
      presentation/
    reader/
      presentation/
    settings/
      data/
      presentation/
    shared/
      presentation/
```

## 打包

安装 Flutter 后，在项目根目录执行：

```powershell
flutter create --platforms=windows,android .
flutter pub get
flutter analyze
flutter run -d windows
```

打包命令：

```powershell
flutter build windows
flutter build apk --release
```

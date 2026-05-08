# paste

一个本地运行的 macOS 菜单栏剪切板历史 App，使用 SwiftUI + AppKit 实现。

## 功能

- 菜单栏常驻入口
- 监听剪切板变化
- 支持文本、URL、图片、文件路径
- SQLite 本地持久化，默认最多保留 100 条、7 天
- 图片保存到 `~/Library/Application Support/paste/images/`
- 搜索剪切板记录
- 点击记录恢复到系统剪切板
- 暂停/恢复记录
- 一键清空
- 收藏记录，收藏内容不会被自动清理
- 敏感内容过滤和默认 App 黑名单
- 主题颜色切换
- 浅色、深色、跟随系统
- 开机启动设置

## 项目结构

```text
paste/
├── ClipMemoryApp.swift
├── AppDelegate.swift
├── Models/
├── Services/
├── Views/
└── Resources/
```

## 构建

当前仓库包含 `paste.xcodeproj`。使用完整 Xcode 打开后，选择 `paste` target 运行即可。

```bash
open paste.xcodeproj
```

如果命令行构建，请先确认 `xcode-select -p` 指向完整 Xcode，而不是 Command Line Tools：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -project paste.xcodeproj -target paste -configuration Debug build
```

## 本地数据

```text
~/Library/Application Support/paste/paste.sqlite
~/Library/Application Support/paste/images/
```

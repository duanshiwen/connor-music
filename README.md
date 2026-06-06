# 康纳音乐

本地 macOS 音乐播放器，Swift + SwiftUI 原生实现。

## 功能

- 🎵 支持主流音频格式（MP3, AAC, WAV, AIFF, M4A, FLAC, OGG 等）
- 📂 自动监视指定文件夹，发现新增音频文件
- 📋 播放列表展示与编排（拖拽排序、搜索过滤、右键删除）
- ⏯️ 播放 / 暂停 / 上一曲 / 下一曲
- 🔀 随机播放 / 全部循环 / 单曲循环
- 🖼️ 自动读取专辑封面和元数据
- ✏️ 支持在播放器内编辑歌曲标题、艺术家和专辑信息
- 🔊 音量跟随系统（无独立音量控制）

## 构建 & 运行

```bash
# 方法 1: 脚本
./build.sh

# 方法 2: 手动
swift build -c release
# .app bundle 在 build/康纳音乐.app
open build/康纳音乐.app

# 方法 3: Xcode（推荐）
open 康纳音乐.xcodeproj
# 在 Xcode 顶部选择「康纳音乐」scheme，然后点击 Run。
# 不要用 Xcode 打开 Package.swift 运行 MusicPlayer scheme；那是 SwiftPM 裸 executable，
# 没有标准 .app bundle，可能出现 missing main bundle identifier 相关启动问题。
```

## 使用

1. 启动后点击顶部「选择音乐文件夹」
2. 选择包含音频文件的文件夹
3. 双击曲目播放，或使用底部控制栏
4. 向文件夹添加新文件会自动出现在播放列表中

## 项目结构

```
Sources/MusicPlayer/
├── App.swift            # 入口
├── Models.swift         # 数据模型
├── AudioEngine.swift    # 播放引擎
├── FolderMonitor.swift  # 文件夹监控
├── PlayerViewModel.swift# 核心逻辑
├── ContentView.swift    # 主界面
├── TrackListView.swift  # 播放列表
├── NowPlayingBar.swift  # 底部控制栏
└── ArtworkView.swift    # 专辑封面组件
```

## 系统要求

- macOS 14.0+
- Swift 6.0+（用于构建）

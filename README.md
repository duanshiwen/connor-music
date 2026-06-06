# 康纳音乐

康纳音乐是一款本地 macOS 音乐播放器，使用 Swift + SwiftUI 原生实现。

当前版本：**1.0.1**

## 功能

- 🎵 支持常见本地音频格式：MP3、AAC、WAV、AIFF、M4A、FLAC、OGG 等
- 📂 自动监视指定音乐文件夹，发现新增音频文件
- 📋 播放列表展示、搜索过滤、右键删除
- ↕️ 支持按「标题 / 艺术家 / 专辑 / 时长」列排序
- ⏯️ 播放 / 暂停 / 上一曲 / 下一曲
- 🔁 一个按钮循环切换播放模式：顺序播放 → 随机播放 → 全部循环 → 单曲循环
- 🖼️ 自动读取专辑封面和音频元数据
- ✏️ 支持在播放器内编辑歌曲标题、艺术家和专辑信息
- 💾 元数据修改会直接写入原始音频文件，不创建 `.bak` 备份
- 🔊 音量跟随系统，无独立音量控制
- 🧩 使用标准 macOS 静态 App 图标资源，不使用运行时图标绘制代码

## 下载 / 安装

当前发布包：

```text
build/康纳音乐-1.0.1.dmg
```

安装方式：

1. 双击打开 `康纳音乐-1.0.1.dmg`
2. 将 `康纳音乐.app` 拖入 `Applications`
3. 从「应用程序」中启动康纳音乐

> 说明：当前本机没有可用的 Apple Developer ID 证书，因此发布包使用 ad-hoc 签名。它适合本地安装和测试；如果要公开分发给其他用户，仍建议使用 Developer ID 签名并完成 notarization 公证。

## 构建 & 运行

### 方法 1：Xcode 运行（推荐）

```bash
open 康纳音乐.xcodeproj
```

然后在 Xcode 顶部选择「康纳音乐」scheme，点击 Run。

建议打开 `康纳音乐.xcodeproj`，它会运行标准 macOS `.app` target。`Package.swift` 保留给命令行 SwiftPM 构建使用。

### 方法 2：脚本构建

```bash
./build.sh
```

脚本会构建并生成：

```text
build/康纳音乐.app
```

### 方法 3：SwiftPM 手动构建

```bash
swift build -c release
```

## 打包发布

当前 1.0.1 发布版使用 Xcode Release 构建，并打包成 DMG。

典型流程：

```bash
APP_NAME="康纳音乐"
VERSION="1.0.1"
BUILD_DIR="build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
DIST_DIR="$BUILD_DIR/release-$VERSION"
DMG_ROOT="$BUILD_DIR/dmg-root-$VERSION"
DMG_PATH="$BUILD_DIR/${APP_NAME}-${VERSION}.dmg"

rm -rf "$DERIVED_DATA" "$DIST_DIR" "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DIST_DIR" "$DMG_ROOT"

xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  clean build

cp -R "$DERIVED_DATA/Build/Products/Release/${APP_NAME}.app" "$DIST_DIR/"

codesign --force --deep --sign - "$DIST_DIR/${APP_NAME}.app"
codesign --verify --deep --strict --verbose=2 "$DIST_DIR/${APP_NAME}.app"

cp -R "$DIST_DIR/${APP_NAME}.app" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

codesign --force --sign - "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"
hdiutil verify "$DMG_PATH"
```

1.0.1 DMG 校验和：

```text
SHA-256: 51b1aab8446bac1e4305c8fc39034eb93561953e5f41566a4ae8bd608dcb705f
```

## 使用

1. 启动后点击顶部「选择音乐文件夹」
2. 选择包含音频文件的文件夹
3. 双击曲目播放，或使用底部控制栏
4. 点击播放列表表头可按标题、艺术家、专辑、时长排序
5. 向音乐文件夹添加新文件后，新文件会自动出现在播放列表中

## 项目结构

```text
Sources/MusicPlayer/
├── App.swift              # 应用入口
├── Models.swift           # 数据模型
├── AudioEngine.swift      # 播放引擎
├── AudioMetadataWriter.swift # 音频元数据写入
├── FolderMonitor.swift    # 文件夹监控
├── MetadataStore.swift    # 元数据存储兼容逻辑
├── PlayerViewModel.swift  # 核心状态与播放逻辑
├── ContentView.swift      # 主界面
├── EditMetadataView.swift # 元数据编辑界面
├── TrackListView.swift    # 播放列表
├── NowPlayingBar.swift    # 底部控制栏
└── ArtworkView.swift      # 专辑封面组件
```

主要资源：

```text
Resources/
├── AppIcon.icns
├── AppIcon.iconset/
├── Assets.xcassets/AppIcon.appiconset/
├── Info.plist
└── XcodeInfo.plist
```

## 系统要求

- macOS 14.0+
- Swift 6.0+（用于构建）
- Xcode 26+（推荐用于标准 `.app` target 构建）

## 仓库

```text
git@github.com:duanshiwen/connor-music.git
```

#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "🎵 Building 康纳音乐..."
swift build -c release 2>&1

# Create app bundle
APP_DIR="build/康纳音乐.app"
BINARY_PATH=$(swift build -c release --show-bin-path)/MusicPlayer

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/MusicPlayer"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/"

echo "✅ Build complete: $APP_DIR"
echo "🚀 Launching..."
open "$APP_DIR"

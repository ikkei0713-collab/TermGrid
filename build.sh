#!/bin/zsh
# TermGrid をビルドして ~/Applications/TermGrid.app に配置する
set -e
cd "$(dirname "$0")"

APP="$HOME/Applications/TermGrid.app"
WORK="./build"

rm -rf "$APP" "$WORK"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$WORK"

# --- アイコン（サイズごとに直接描画して .icns にまとめる）
swiftc -O -o "$WORK/makeicon" makeicon.swift -framework Cocoa
"$WORK/makeicon" "$WORK/TermGrid.iconset"
iconutil -c icns "$WORK/TermGrid.iconset" -o "$APP/Contents/Resources/TermGrid.icns"

# --- 本体
swiftc -O -o "$APP/Contents/MacOS/TermGrid" main.swift -framework Cocoa

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>            <string>TermGrid</string>
  <key>CFBundleDisplayName</key>     <string>TermGrid</string>
  <key>CFBundleExecutable</key>      <string>TermGrid</string>
  <key>CFBundleIdentifier</key>      <string>local.ikkeitanaka.TermGrid</string>
  <key>CFBundleIconFile</key>        <string>TermGrid</string>
  <key>CFBundlePackageType</key>     <string>APPL</string>
  <key>CFBundleShortVersionString</key> <string>1.0</string>
  <key>CFBundleVersion</key>         <string>1</string>
  <key>LSMinimumSystemVersion</key>  <string>13.0</string>
  <key>LSUIElement</key>             <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>ターミナルのウィンドウを開いて整列するために操作します。</string>
</dict>
</plist>
PLIST

# 署名がないとオートメーション権限が毎回リセットされるため ad-hoc 署名する
codesign --force --sign - "$APP"

# Finder のアイコンキャッシュを更新させる
touch "$APP"

echo "built: $APP"

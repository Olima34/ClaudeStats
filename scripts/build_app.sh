#!/bin/zsh
# Builds ClaudeStats.app (release) and installs it in ~/Applications.
# Usage: ./scripts/build_app.sh [--no-install]
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

APP_NAME="ClaudeStats"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
VERSION="1.0.0"

echo "→ Compilation (release)…"
swift build -c release

echo "→ Icône…"
ICON_WORK="$BUILD_DIR/icon"
rm -rf "$ICON_WORK"
mkdir -p "$ICON_WORK/AppIcon.iconset"
swift "$ROOT/scripts/make_icon.swift" "$ICON_WORK/icon-1024.png" >/dev/null
for s in 16 32 128 256 512; do
  sips -z $s $s "$ICON_WORK/icon-1024.png" --out "$ICON_WORK/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d "$ICON_WORK/icon-1024.png" --out "$ICON_WORK/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICON_WORK/AppIcon.iconset" -o "$ICON_WORK/AppIcon.icns"

echo "→ Assemblage de $APP_NAME.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ICON_WORK/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>ClaudeStats</string>
  <key>CFBundleIdentifier</key><string>local.claudestats.app</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleDevelopmentRegion</key><string>fr</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Statistiques locales de tes sessions Claude</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

if [[ "${1:-}" != "--no-install" ]]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
  rm -rf "$DEST/$APP_NAME.app"
  cp -R "$APP" "$DEST/"
  echo "✓ Installée dans $DEST/$APP_NAME.app"
else
  echo "✓ App prête : $APP"
fi

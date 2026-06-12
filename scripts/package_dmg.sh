#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
STAGING_DIR="$BUILD_DIR/dmg-root"
APP_NAME="wangcl"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"

build_with_xcodebuild() {
  local xcodebuild_cmd=(xcodebuild)

  if ! xcodebuild -version >/dev/null 2>&1; then
    if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
      xcodebuild_cmd=(xcrun xcodebuild)
      export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    else
      return 1
    fi
  fi

  "${xcodebuild_cmd[@]}" \
    -project "$ROOT_DIR/paste.xcodeproj" \
    -target paste \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    build
}

build_with_swiftc() {
  local sdk_path
  sdk_path="$(xcrun --sdk macosx --show-sdk-path)"

  mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

  swiftc \
    -O \
    -sdk "$sdk_path" \
    -target arm64-apple-macos13.0 \
    "$ROOT_DIR"/paste/*.swift \
    "$ROOT_DIR"/paste/Models/*.swift \
    "$ROOT_DIR"/paste/Services/*.swift \
    "$ROOT_DIR"/paste/Views/*.swift \
    -lsqlite3 \
    -o "$APP_PATH/Contents/MacOS/$APP_NAME"

  cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>local.paste</string>
  <key>CFBundleIconFile</key>
  <string>Wangcl</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

  cp "$ROOT_DIR/paste/Resources/Wangcl.icns" "$APP_PATH/Contents/Resources/Wangcl.icns"

  codesign --force --deep --sign - "$APP_PATH" >/dev/null
}

rm -rf "$DERIVED_DATA" "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$BUILD_DIR" "$STAGING_DIR"

if ! build_with_xcodebuild; then
  echo "Full Xcode is unavailable; building with swiftc instead."
  build_with_swiftc
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded, but $APP_PATH was not found." >&2
  exit 1
fi

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created $DMG_PATH"
echo "Open the DMG, then drag $APP_NAME.app to Applications."

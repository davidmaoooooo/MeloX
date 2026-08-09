#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build}"
PROJECT="$ROOT/MeloX.xcodeproj"
SCHEME="MeloX Desktop"
APP_NAME="MeloX Desktop"
DERIVED_DATA="$BUILD/DerivedData-macOS"
STAGING="$BUILD/DMG"
DMG_PATH="$BUILD/MeloX-macOS.dmg"
RELEASE_NOTES_PATH="$BUILD/ReleaseNotes.json"
RELEASE_NOTES_MARKDOWN_PATH="$BUILD/ReleaseNotes.md"

rm -rf -- "$DERIVED_DATA" "$STAGING"
rm -f -- "$DMG_PATH" "$RELEASE_NOTES_PATH" "$RELEASE_NOTES_MARKDOWN_PATH"
mkdir -p "$BUILD"

echo "========== 构建 macOS Release =========="

xcodebuild clean build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM=""

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Release" -maxdepth 2 -name "$APP_NAME.app" -type d -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "找不到 macOS 构建产物：$APP_NAME.app"
  exit 1
fi
if [[ ! -f "$APP_PATH/Contents/Resources/ReleaseNotes.json" || \
      ! -f "$APP_PATH/Contents/Resources/ReleaseNotes.md" ]]; then
  echo "macOS 构建产物中缺少更新日志"
  exit 1
fi

ACTUAL_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
if [[ "$ACTUAL_BUNDLE_ID" != "azki.moye.MeloX.desktop" ]]; then
  echo "MeloX Desktop Bundle ID 不正确：$ACTUAL_BUNDLE_ID"
  exit 1
fi

ditto --norsrc "$APP_PATH/Contents/Resources/ReleaseNotes.json" "$RELEASE_NOTES_PATH"
ditto --norsrc "$APP_PATH/Contents/Resources/ReleaseNotes.md" "$RELEASE_NOTES_MARKDOWN_PATH"

echo "========== 生成 DMG =========="

mkdir -p "$STAGING"
STAGED_APP="$STAGING/$APP_NAME.app"
ditto --norsrc "$APP_PATH" "$STAGED_APP"
ln -s /Applications "$STAGING/Applications"

codesign \
  --force \
  --deep \
  --sign - \
  --entitlements "$ROOT/MeloXDesktop/MeloXDesktop.entitlements" \
  "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"

hdiutil create \
  -volname "MeloX" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

hdiutil imageinfo "$DMG_PATH" > /dev/null
ls -lh "$DMG_PATH"
echo "已生成：$DMG_PATH"

#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build}"
PROJECT="$ROOT/MeloX.xcodeproj"
SCHEME="MeloX Desktop"
APP_NAME="MeloX Desktop"
RELEASE_NOTES_PATH="$BUILD/ReleaseNotes.json"
RELEASE_NOTES_MARKDOWN_PATH="$BUILD/ReleaseNotes.md"

read -r -a ARCHITECTURES <<< "${MELOX_MAC_ARCHS:-arm64 x86_64}"
if [[ "${#ARCHITECTURES[@]}" -eq 0 ]]; then
  echo "MELOX_MAC_ARCHS 至少需要一个架构"
  exit 1
fi

mkdir -p "$BUILD"
rm -f -- \
  "$BUILD/MeloX-macOS.dmg" \
  "$BUILD/MeloX-macOS-Apple-Silicon.dmg" \
  "$BUILD/MeloX-macOS-Intel.dmg" \
  "$RELEASE_NOTES_PATH" \
  "$RELEASE_NOTES_MARKDOWN_PATH"

METADATA_INITIALIZED=false

for ARCHITECTURE in "${ARCHITECTURES[@]}"; do
  case "$ARCHITECTURE" in
    arm64)
      VARIANT_NAME="Apple Silicon"
      FILE_VARIANT="Apple-Silicon"
      ;;
    x86_64)
      VARIANT_NAME="Intel"
      FILE_VARIANT="Intel"
      ;;
    *)
      echo "不支持的 macOS 架构：$ARCHITECTURE（仅支持 arm64 和 x86_64）"
      exit 1
      ;;
  esac

  DERIVED_DATA="$BUILD/DerivedData-macOS-$ARCHITECTURE"
  STAGING="$BUILD/DMG-$ARCHITECTURE"
  DMG_PATH="$BUILD/MeloX-macOS-$FILE_VARIANT.dmg"

  rm -rf -- "$DERIVED_DATA" "$STAGING"
  rm -f -- "$DMG_PATH"

  echo "========== 构建 macOS $VARIANT_NAME Release =========="

  xcodebuild clean build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    ARCHS="$ARCHITECTURE" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    DEVELOPMENT_TEAM=""

  APP_PATH="$(find "$DERIVED_DATA/Build/Products/Release" -maxdepth 2 -name "$APP_NAME.app" -type d -print -quit)"
  if [[ -z "$APP_PATH" ]]; then
    echo "找不到 macOS $VARIANT_NAME 构建产物：$APP_NAME.app"
    exit 1
  fi
  if [[ ! -f "$APP_PATH/Contents/Resources/ReleaseNotes.json" || \
        ! -f "$APP_PATH/Contents/Resources/ReleaseNotes.md" ]]; then
    echo "macOS $VARIANT_NAME 构建产物中缺少更新日志"
    exit 1
  fi

  ACTUAL_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
  if [[ "$ACTUAL_BUNDLE_ID" != "azki.moye.MeloX.desktop" ]]; then
    echo "MeloX Desktop Bundle ID 不正确：$ACTUAL_BUNDLE_ID"
    exit 1
  fi

  EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Contents/Info.plist")"
  EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
  ACTUAL_ARCHITECTURES="$(lipo -archs "$EXECUTABLE_PATH")"
  if [[ "$ACTUAL_ARCHITECTURES" != "$ARCHITECTURE" ]]; then
    echo "MeloX Desktop $VARIANT_NAME 架构不正确：期望 $ARCHITECTURE，实际 $ACTUAL_ARCHITECTURES"
    exit 1
  fi

  if [[ "$METADATA_INITIALIZED" == false ]]; then
    ditto --norsrc "$APP_PATH/Contents/Resources/ReleaseNotes.json" "$RELEASE_NOTES_PATH"
    ditto --norsrc "$APP_PATH/Contents/Resources/ReleaseNotes.md" "$RELEASE_NOTES_MARKDOWN_PATH"
    METADATA_INITIALIZED=true
  else
    if ! cmp --silent "$APP_PATH/Contents/Resources/ReleaseNotes.json" "$RELEASE_NOTES_PATH" || \
       ! cmp --silent "$APP_PATH/Contents/Resources/ReleaseNotes.md" "$RELEASE_NOTES_MARKDOWN_PATH"; then
      echo "macOS Apple Silicon 与 Intel 构建的更新日志不一致"
      exit 1
    fi
  fi

  echo "========== 生成 macOS $VARIANT_NAME DMG =========="

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
  echo "已生成 $VARIANT_NAME 版：$DMG_PATH"
done

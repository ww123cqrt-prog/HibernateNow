#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="HibernateNow"
DISPLAY_NAME="电源管理"
BUNDLE_ID="com.cq.HibernateNow"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="$(cat "$ROOT_DIR/VERSION")"
APP_BUNDLE="$ROOT_DIR/dist/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
INSTALLED_APP="$HOME/Applications/$DISPLAY_NAME.app"
LEGACY_INSTALLED_APP="$HOME/Applications/$APP_NAME.app"
LEGACY_BACKUP_APP="$HOME/Applications/.HibernateNow-backups/HibernateNow-$(date -u +%Y%m%dT%H%M%SZ)-$$.app"

case "$MODE" in
  run|--debug|--logs|--telemetry|--verify) BUILD_CONFIGURATION="debug" ;;
  --install|--build) BUILD_CONFIGURATION="release" ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--build|--install]" >&2
    exit 2
    ;;
esac

if [[ "$MODE" != "--install" && "$MODE" != "--build" ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

swift build -c "$BUILD_CONFIGURATION" --package-path "$ROOT_DIR"
BUILD_BINARY="$(swift build -c "$BUILD_CONFIGURATION" --package-path "$ROOT_DIR" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_CONTENTS/Resources"
cp "$BUILD_BINARY" "$APP_MACOS/$APP_NAME"
if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
  # Remove debug records containing local source paths before signing the bundle.
  /usr/bin/strip -S "$APP_MACOS/$APP_NAME"
fi
cp "$ROOT_DIR/Resources/HibernateNow.icns" "$APP_CONTENTS/Resources/HibernateNow.icns"
cp "$ROOT_DIR/LICENSE" "$APP_CONTENTS/Resources/LICENSE"
mkdir -p "$APP_CONTENTS/Resources/DockIcons"
cp "$ROOT_DIR/Resources/DockIcons/"*.icns "$APP_CONTENTS/Resources/DockIcons/"
chmod +x "$APP_MACOS/$APP_NAME"

cat >"$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
  <key>CFBundleVersion</key><string>11</string>
  <key>CFBundleIconFile</key><string>HibernateNow</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSAppleEventsUsageDescription</key><string>用于一次性启用或关闭本机固定电源命令的免密权限。</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --build)
    ;;
  run)
    open_app
    ;;
  --debug)
    lldb -- "$APP_MACOS/$APP_NAME"
    ;;
  --logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --install)
    mkdir -p "$(dirname "$INSTALLED_APP")"
    STAGED_APP="$HOME/Applications/$DISPLAY_NAME.app.staged.$$"
    PREVIOUS_APP="$HOME/Applications/$DISPLAY_NAME.app.previous.$$"
    ditto "$APP_BUNDLE" "$STAGED_APP"
    codesign --verify --deep --strict "$STAGED_APP"
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    MIGRATED_LEGACY=false
    if [[ -d "$LEGACY_INSTALLED_APP" ]]; then
      mkdir -p "$(dirname "$LEGACY_BACKUP_APP")"
      if [[ -e "$LEGACY_BACKUP_APP" ]]; then
        echo "legacy backup already exists: $LEGACY_BACKUP_APP" >&2
        exit 1
      fi
      mv "$LEGACY_INSTALLED_APP" "$LEGACY_BACKUP_APP"
      MIGRATED_LEGACY=true
    fi
    if [[ -d "$INSTALLED_APP" ]]; then
      mv "$INSTALLED_APP" "$PREVIOUS_APP"
    fi
    if ! mv "$STAGED_APP" "$INSTALLED_APP"; then
      if [[ -d "$PREVIOUS_APP" ]]; then mv "$PREVIOUS_APP" "$INSTALLED_APP"; fi
      if [[ "$MIGRATED_LEGACY" == true ]]; then mv "$LEGACY_BACKUP_APP" "$LEGACY_INSTALLED_APP"; fi
      exit 1
    fi
    rm -rf "$PREVIOUS_APP"
    codesign --verify --deep --strict "$INSTALLED_APP"
    /usr/bin/open -n "$INSTALLED_APP"
    ;;
esac

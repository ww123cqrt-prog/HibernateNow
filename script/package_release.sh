#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
./script/build_and_run.sh --build
APP_BUNDLE="$ROOT_DIR/dist/电源管理.app"
APP_VERSION="$(cat VERSION)"
ARCH="$(/usr/bin/lipo -archs "$APP_BUNDLE/Contents/MacOS/HibernateNow")"
case "$ARCH" in arm64|x86_64) ;; *) echo "Unsupported package architecture: $ARCH" >&2; exit 1 ;; esac
PACKAGE_NAME="HibernateNow-$APP_VERSION-$ARCH"
STAGING_DIR="$(/usr/bin/mktemp -d "$ROOT_DIR/.build/release.XXXXXX")"
trap '/bin/rm -rf "$STAGING_DIR"' EXIT

/usr/bin/ditto "$APP_BUNDLE" "$STAGING_DIR/电源管理.app"
/bin/ln -s /Applications "$STAGING_DIR/Applications"
/bin/cp LICENSE "$STAGING_DIR/LICENSE.txt"
/bin/cp docs/INSTALL.zh-CN.txt "$STAGING_DIR/安装说明.txt"
/usr/bin/hdiutil create -quiet -ov -format UDZO -fs HFS+ \
  -volname "Power Manager $APP_VERSION" -srcfolder "$STAGING_DIR" \
  "$ROOT_DIR/dist/$PACKAGE_NAME.dmg"
python3 script/record_release.py "$APP_BUNDLE" "$ROOT_DIR/dist/$PACKAGE_NAME.dmg"
printf 'Created %s\n' "$ROOT_DIR/dist/$PACKAGE_NAME.dmg"

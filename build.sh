#!/bin/bash
set -e

APP_NAME="Codex Switch"

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

if [ -z "${CLANG_MODULE_CACHE_PATH:-}" ]; then
    export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/codex-switch-module-cache"
fi

echo "Building ${APP_NAME}..."
swiftc CodexSwitcher.swift -o "${APP_NAME}" \
    -framework AppKit \
    -framework UserNotifications \
    -framework ServiceManagement \
    -O

# Update app bundle
mkdir -p "${APP_NAME}.app/Contents/MacOS"
cp "${APP_NAME}" "${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
cp Info.plist "${APP_NAME}.app/Contents/Info.plist"
mkdir -p "${APP_NAME}.app/Contents/Resources"
cp AppIcon.icns "${APP_NAME}.app/Contents/Resources/AppIcon.icns"

echo "Done. Run with: open '${APP_NAME}.app'"

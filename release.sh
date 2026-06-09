#!/bin/bash
set -euo pipefail

APP_NAME="Codex Switch"
VERSION="2.0"
DMG_NAME="Codex-Switch-v${VERSION}.dmg"
STAGING_DIR="release"

bash build.sh

rm -rf "${STAGING_DIR}" "${DMG_NAME}"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_NAME}.app" "${STAGING_DIR}/"
cp LICENSE "${STAGING_DIR}/LICENSE"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_NAME}"

rm -rf "${STAGING_DIR}"

echo "Created ${DMG_NAME}"

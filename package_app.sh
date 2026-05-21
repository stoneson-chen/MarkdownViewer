#!/bin/bash
# Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
# CHENXX.ORG 版权所有，全球范围内保留所有权利。
# 项目名称：MarkdownViewer（墨阅）
# 开发人员：Chen Xinxing（陈新兴）
# 创建日期：2026
#
# Licensed under the MIT License.
# See the LICENSE file in the project root for full license text.


set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
APP_NAME="MarkdownViewer.app"
APP_DIR="${PROJECT_DIR}/${APP_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

rm -rf "${APP_DIR}"

echo "🧹 Cleaning SPM build artifacts..."
swift package clean

echo "🔨 Compiling in release mode..."
if ! swift build -c release --disable-sandbox -j 1; then
    echo "⚠️  First release build failed. Waiting 2s in case an editor was saving Sources/, then retry once..."
    sleep 2
    swift build -c release --disable-sandbox -j 1
fi

mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${PROJECT_DIR}/.build/release/MarkdownViewer" "${MACOS_DIR}/MarkdownViewer"

cp "${PROJECT_DIR}/Info.plist" "${CONTENTS_DIR}/Info.plist"

cp "${PROJECT_DIR}/MarkdownViewer.entitlements" "${CONTENTS_DIR}/MarkdownViewer.entitlements"

if [ -f "${PROJECT_DIR}/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

BUNDLE_RESOURCES="${PROJECT_DIR}/.build/release/MarkdownViewer_MarkdownViewer.bundle"
if [ -d "${BUNDLE_RESOURCES}" ]; then
    echo "📦 Copying SPM resource bundle..."
    cp -R "${BUNDLE_RESOURCES}" "${RESOURCES_DIR}/"
    
    if [ -d "${RESOURCES_DIR}/MarkdownViewer_MarkdownViewer.bundle/zh-hans.lproj" ]; then
        mv "${RESOURCES_DIR}/MarkdownViewer_MarkdownViewer.bundle/zh-hans.lproj" "${RESOURCES_DIR}/MarkdownViewer_MarkdownViewer.bundle/zh-Hans.lproj"
    fi
else
    echo "⚠️ Warning: Resource bundle not found at ${BUNDLE_RESOURCES}"
fi

echo "📦 Syncing localizations to root Resources..."
cp -R "${PROJECT_DIR}/Sources/Resources/"*.lproj "${RESOURCES_DIR}/"

echo "🎨 Updating default.css..."
if [ -d "${RESOURCES_DIR}/MarkdownViewer_MarkdownViewer.bundle" ]; then
    cp "${PROJECT_DIR}/Sources/Resources/default.css" "${RESOURCES_DIR}/MarkdownViewer_MarkdownViewer.bundle/default.css"
fi

echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

cat > "${MACOS_DIR}/mdview" << 'EOF'
DIR="$(cd "$(dirname "$0")" && pwd)"
"${DIR}/MarkdownViewer" "$@"
EOF
chmod +x "${MACOS_DIR}/mdview"

CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
echo "🔐 Signing app with entitlements..."
codesign --force --deep --sign "${CODE_SIGN_IDENTITY}" \
    --entitlements "${PROJECT_DIR}/MarkdownViewer.entitlements" \
    "${APP_DIR}"

echo "🔍 Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"
codesign -d --entitlements :- "${APP_DIR}" >/dev/null

echo "💿 Packaging DMG..."
DMG_NAME="MarkdownViewer.dmg"
rm -f "${PROJECT_DIR}/${DMG_NAME}"
hdiutil create -volname "MarkdownViewer" -srcfolder "${APP_DIR}" -ov -format UDZO "${PROJECT_DIR}/${DMG_NAME}"
echo "✅ Successfully created DMG: ${PROJECT_DIR}/${DMG_NAME}"

echo "✅ Successfully packaged: ${APP_DIR}"
echo ""
echo "To install:"
echo "  1. Double-click ${APP_NAME} in Finder to run"
echo "  2. Or drag it to /Applications"
echo ""
echo "CLI usage:"
echo "  open -a '${APP_DIR}' /path/to/file.md"
echo "  # Or create a symlink:"
echo "  ln -sf '${APP_DIR}/Contents/MacOS/mdview' /usr/local/bin/mdview"
echo ""
ls -la "${APP_DIR}"

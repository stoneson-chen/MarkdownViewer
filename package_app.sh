#!/bin/bash
# Package MarkdownViewer as a macOS .app bundle

set -e

PROJECT_DIR="/Users/chenxx/Projects/markdownViewer/MarkdownViewer"
APP_NAME="MarkdownViewer.app"
APP_DIR="${PROJECT_DIR}/${APP_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Clean previous build
rm -rf "${APP_DIR}"

# Recompile (clean first: avoids odd incremental state; -j 1 reduces races if multiple
# frontends touch the same module. If you still see "input file was modified during
# the build", pause editor auto-save / format-on-save for Sources/ while this runs.)
echo "🧹 Cleaning SPM build artifacts..."
swift package clean

echo "🔨 Compiling in release mode..."
if ! swift build -c release --disable-sandbox -j 1; then
    echo "⚠️  First release build failed. Waiting 2s in case an editor was saving Sources/, then retry once..."
    sleep 2
    swift build -c release --disable-sandbox -j 1
fi

# Create .app bundle structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy executable
cp "${PROJECT_DIR}/.build/release/MarkdownViewer" "${MACOS_DIR}/MarkdownViewer"

# Copy Info.plist
cp "${PROJECT_DIR}/Info.plist" "${CONTENTS_DIR}/Info.plist"

# Copy entitlements (for reference)
cp "${PROJECT_DIR}/MarkdownViewer.entitlements" "${CONTENTS_DIR}/MarkdownViewer.entitlements"

# Copy app icon if exists
if [ -f "${PROJECT_DIR}/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# Copy bundled resources (SPM creates this bundle for resources)
BUNDLE_RESOURCES="${PROJECT_DIR}/.build/release/MarkdownViewer_MarkdownViewer.bundle"
if [ -d "${BUNDLE_RESOURCES}" ]; then
    echo "📦 Copying SPM resource bundle..."
    cp -R "${BUNDLE_RESOURCES}" "${RESOURCES_DIR}/"
    
    # Fix potential case sensitivity issues for Chinese localization
    # SPM often normalizes to lowercase, but macOS might expect zh-Hans
    if [ -d "${RESOURCES_DIR}/MarkdownViewer_MarkdownViewer.bundle/zh-hans.lproj" ]; then
        mv "${RESOURCES_DIR}/MarkdownViewer_MarkdownViewer.bundle/zh-hans.lproj" "${RESOURCES_DIR}/MarkdownViewer_MarkdownViewer.bundle/zh-Hans.lproj"
    fi
else
    echo "⚠️ Warning: Resource bundle not found at ${BUNDLE_RESOURCES}"
fi

# Copy localizations to root Resources for Bundle.main access as well
echo "📦 Syncing localizations to root Resources..."
cp -R "${PROJECT_DIR}/Sources/Resources/"*.lproj "${RESOURCES_DIR}/"

# Force update default.css in the bundle
echo "🎨 Updating default.css..."
if [ -d "${RESOURCES_DIR}/MarkdownViewer_MarkdownViewer.bundle" ]; then
    cp "${PROJECT_DIR}/Sources/Resources/default.css" "${RESOURCES_DIR}/MarkdownViewer_MarkdownViewer.bundle/default.css"
fi

# Create PkgInfo
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# Create CLI symlink helper script
cat > "${MACOS_DIR}/mdview" << 'EOF'
#!/bin/bash
# CLI helper: mdview /path/to/file.md
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

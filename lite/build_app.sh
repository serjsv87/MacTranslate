#!/bin/bash
set -e

echo "============================================="
echo "   Building MacTranslate macOS Application   "
echo "============================================="

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

APP_NAME="MacTranslate"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"

echo "1. Compiling Release Binary..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)"
RELEASE_BIN="${BIN_PATH}/${APP_NAME}"
if [ ! -f "$RELEASE_BIN" ]; then
    RELEASE_BIN="$(find .build -type f -name "${APP_NAME}" -perm +111 2>/dev/null | grep -i release | head -n 1)"
fi
if [ -z "$RELEASE_BIN" ] || [ ! -f "$RELEASE_BIN" ]; then
    echo "Error: Release binary not found for ${APP_NAME}"
    exit 1
fi

echo "2. Creating App Bundle Structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "$RELEASE_BIN" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

echo "3. Writing Info.plist..."
cat << 'EOF' > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MacTranslate</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.mactranslate.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MacTranslate</string>
    <key>CFBundleDisplayName</key>
    <string>MacTranslate</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 MacTranslate. All rights reserved.</string>
</dict>
</plist>
EOF

echo "✓ ${APP_BUNDLE} created successfully!"

echo "4. Packaging into ${DMG_NAME}..."
DMG_TEMP_DIR="$(mktemp -d -t mactranslate_dmg)"
cp -R "${APP_BUNDLE}" "${DMG_TEMP_DIR}/"
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

rm -f "${DMG_NAME}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TEMP_DIR}" -ov -format UDZO "${DMG_NAME}"
rm -rf "${DMG_TEMP_DIR}"

echo "============================================="
echo "  SUCCESS! MacTranslate Application & DMG Ready!"
echo "  - Bundle: ${PROJECT_DIR}/${APP_BUNDLE}"
echo "  - DMG:    ${PROJECT_DIR}/${DMG_NAME}"
echo "============================================="

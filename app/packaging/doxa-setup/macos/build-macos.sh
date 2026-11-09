#!/bin/bash
set -euo pipefail

# Mac build: no instantView redistribution, no privileged operations.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
VERSION="0.1.0"
PRODUCT="Standivarius Doxa Setup"
BASENAME="Standivarius-Doxa-Installer-v${VERSION}-MAC-UNSIGNED"
BUNDLE_ID="com.standivarius.doxa.setup"
BUILD_DIR="${1:-${RUNNER_TEMP:-/tmp}/doxa-macos-build}"
APP="$BUILD_DIR/$PRODUCT.app"
OUTPUT="$BUILD_DIR/dist"
SRC="$SCRIPT_DIR/StandivariusDoxaSetup.swift"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: macOS build requires Xcode on a real macOS host." >&2
  exit 2
fi
if [[ -e "$BUILD_DIR" ]]; then
  echo "ERROR: Build output already exists: $BUILD_DIR (refusing overwrite)." >&2
  exit 3
fi

SDK="$(xcrun --sdk macosx --show-sdk-path)"
mkdir -p "$BUILD_DIR/bin" "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUTPUT"
for ARCH in arm64 x86_64; do
  echo "Building for ${ARCH}"
  xcrun swiftc -parse-as-library -O \
    -sdk "$SDK" -target "${ARCH}-apple-macos13.0" \
    -framework AppKit -framework SwiftUI \
    -o "$BUILD_DIR/bin/DoxaSetup-$ARCH" "$SRC"
done
lipo -create \
  "$BUILD_DIR/bin/DoxaSetup-arm64" \
  "$BUILD_DIR/bin/DoxaSetup-x86_64" \
  -output "$APP/Contents/MacOS/DoxaSetup"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>${PRODUCT}</string>
    <key>CFBundleDisplayName</key><string>${PRODUCT}</string>
    <key>CFBundleExecutable</key><string>DoxaSetup</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict>
</plist>
EOF

plutil -lint "$APP/Contents/Info.plist"
# Ad-hoc only: structural signature, not identified/notarised customer software.
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
lipo -verify_arch arm64 x86_64 "$APP/Contents/MacOS/DoxaSetup"

# PKG is unsigned and has no pre/postinstall scripts.
PAYLOAD="$BUILD_DIR/package-root"
mkdir -p "$PAYLOAD/Applications"
ditto "$APP" "$PAYLOAD/Applications/$PRODUCT.app"
PKG="$OUTPUT/$BASENAME.pkg"
pkgbuild --root "$PAYLOAD" \
  --identifier "$BUNDLE_ID" \
  --version "$VERSION" \
  --install-location "/" \
  "$PKG"

# DMG provides a drag-to-Applications experience without root.
DMG_ROOT="$BUILD_DIR/dmg-root"
mkdir -p "$DMG_ROOT"
ditto "$APP" "$DMG_ROOT/$PRODUCT.app"
ln -s /Applications "$DMG_ROOT/Applications"
DMG="$OUTPUT/$BASENAME.dmg"
hdiutil create -quiet -fs HFS+ -format UDZO -volname "$PRODUCT" -srcfolder "$DMG_ROOT" -ov "$DMG"

cp "$SCRIPT_DIR/README.md" "$OUTPUT/README-MACOS.txt"
(
 cd "$OUTPUT"
 shasum -a 256 ./*.pkg ./*.dmg > SHA256SUMS.txt
)
if [[ -n "${GITHUB_SHA:-}" ]]; then
  printf '%s\n' "$GITHUB_SHA" > "$OUTPUT/SOURCE-COMMIT.txt"
else
  git -C "$REPO" rev-parse HEAD > "$OUTPUT/SOURCE-COMMIT.txt"
fi

"$SCRIPT_DIR/test-macos.sh" "$BUILD_DIR"
echo "MACOS_UNSIGNED_PREVIEW_BUILD_PASS: $OUTPUT"

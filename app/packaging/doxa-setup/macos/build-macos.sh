#!/bin/bash
set -euo pipefail

# Mac build: no instantView redistribution, no privileged operations.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
VERSION="0.1.0"
PRODUCT="Standivarius Doxa Setup"
# Explicit release mode never silently falls back to ad-hoc signing.
RELEASE="${DOXA_MACOS_RELEASE:-0}"
if [[ "$RELEASE" != "0" && "$RELEASE" != "1" ]]; then
  echo "ERROR: DOXA_MACOS_RELEASE must be 0 or 1." >&2
  exit 2
fi
if [[ "$RELEASE" == "1" ]]; then
  : "${DOXA_MAC_DEVELOPER_ID_APP:?Set Developer ID Application identity}"
  : "${DOXA_MAC_DEVELOPER_ID_INSTALLER:?Set Developer ID Installer identity}"
  : "${DOXA_MAC_NOTARY_PROFILE:?Set local notarytool keychain profile}"
  BASENAME="Standivarius-Doxa-Installer-v${VERSION}"
else
  BASENAME="Standivarius-Doxa-Installer-v${VERSION}-MAC-UNSIGNED"
fi
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
if [[ "$RELEASE" == "1" ]]; then
  # Hardened runtime and secure timestamp are mandatory for distribution.
  codesign --force --options runtime --timestamp \
    --sign "$DOXA_MAC_DEVELOPER_ID_APP" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
else
  # Review build only: ad-hoc signature is not a publisher signature.
  codesign --force --sign - --timestamp=none "$APP"
  codesign --verify --deep --strict "$APP"
fi
lipo "$APP/Contents/MacOS/DoxaSetup" -verify_arch arm64 x86_64

# PKG is unsigned and has no pre/postinstall scripts.
PAYLOAD="$BUILD_DIR/package-root"
mkdir -p "$PAYLOAD/Applications"
ditto "$APP" "$PAYLOAD/Applications/$PRODUCT.app"
PKG="$OUTPUT/$BASENAME.pkg"
# macOS runners still use Bash 3.2; with set -u, expanding an empty
# bash array is an error. Keep the two invocations explicit.
if [[ "$RELEASE" == "1" ]]; then
  pkgbuild --root "$PAYLOAD" \
    --identifier "$BUNDLE_ID" --version "$VERSION" \
    --install-location "/" \
    --sign "$DOXA_MAC_DEVELOPER_ID_INSTALLER" --timestamp "$PKG"
else
  pkgbuild --root "$PAYLOAD" \
    --identifier "$BUNDLE_ID" --version "$VERSION" \
    --install-location "/" "$PKG"
fi

# DMG provides a drag-to-Applications experience without root.
DMG_ROOT="$BUILD_DIR/dmg-root"
mkdir -p "$DMG_ROOT"
ditto "$APP" "$DMG_ROOT/$PRODUCT.app"
ln -s /Applications "$DMG_ROOT/Applications"
DMG="$OUTPUT/$BASENAME.dmg"
hdiutil create -quiet -fs HFS+ -format UDZO -volname "$PRODUCT" -srcfolder "$DMG_ROOT" -ov "$DMG"

if [[ "$RELEASE" == "1" ]]; then
  # Apple must accept both independently distributed containers.
  pkgutil --check-signature "$PKG"
  for artifact in "$PKG" "$DMG"; do
    xcrun notarytool submit "$artifact" \
      --keychain-profile "$DOXA_MAC_NOTARY_PROFILE" --wait
    xcrun stapler staple "$artifact"
    xcrun stapler validate "$artifact"
  done
fi

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

bash "$SCRIPT_DIR/test-macos.sh" "$BUILD_DIR"
if [[ "$RELEASE" == "1" ]]; then
  echo "MACOS_SIGNED_NOTARISED_BUILD_PASS: $OUTPUT"
else
  echo "MACOS_UNSIGNED_PREVIEW_BUILD_PASS: $OUTPUT"
fi

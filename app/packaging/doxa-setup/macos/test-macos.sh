#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/StandivariusDoxaSetup.swift"
BUILD_DIR="${1:---source-only}"
VERSION="0.1.0"
BASENAME="Standivarius-Doxa-Installer-v${VERSION}-MAC-UNSIGNED"

# Explicitly pin the vendor download URL, don't include vendor binaries.
grep -Fq 'https://www.siliconmotion.com/downloads/SM770-drivers.html' "$SOURCE"
grep -Fq 'Screen & System Audio Recording' "$SOURCE"
grep -Fq 'macOS Displays settings' "$SOURCE"
grep -Fq 'NSWorkspace.shared.runningApplications' "$SOURCE"
grep -Fq 'NSScreen.screens.count' "$SOURCE"
grep -Fq 'No automatic' "$SCRIPT_DIR/README.md"

if grep -Eiq '(^|[^a-z])(sudo|tccutil|spctl|csrutil|kextload|launchctl|diskutil|installer -pkg)([^a-z]|$)' "$SOURCE"; then
  echo 'Blocked privileged command or security bypass in Mac application source.' >&2
  exit 1
fi
if grep -Eiq 'AppTransportSecurity|NSCameraUsageDescription|NSMicrophoneUsageDescription|NSScreenCaptureUsageDescription' "$SOURCE"; then
  echo 'Unexpected sensitive data collection added to guided installer.' >&2
  exit 1
fi
if grep -Eq 'https://doxa-installer-assistant|/v1/ask' "$SOURCE"; then
  echo 'Mac AI service is unqualified: cannot enable Windows-only backend.' >&2
  exit 1
fi

if [[ "$BUILD_DIR" == "--source-only" ]]; then
  echo 'MACOS_SOURCE_CONTRACT_PASS'
  exit 0
fi

[[ "$(uname -s)" == "Darwin" ]]
APP="$BUILD_DIR/Standivarius Doxa Setup.app"
DIST="$BUILD_DIR/dist"
PKG="$DIST/$BASENAME.pkg"
DMG="$DIST/$BASENAME.dmg"
[[ -x "$APP/Contents/MacOS/DoxaSetup" ]]
[[ -s "$PKG" && -s "$DMG" ]]
lipo "$APP/Contents/MacOS/DoxaSetup" -verify_arch arm64 x86_64
plutil -lint "$APP/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" == "com.standivarius.doxa.setup" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" == "$VERSION" ]]
codesign --verify --deep --strict "$APP"

EXPANDED="$(mktemp -d)"
trap 'rm -rf "$EXPANDED"' EXIT
pkgutil --expand "$PKG" "$EXPANDED/package"
[[ -f "$EXPANDED/package/Payload" ]]
[[ ! -d "$EXPANDED/package/Scripts" ]]
pkgutil --payload-files "$PKG" | grep -Fq 'Standivarius Doxa Setup.app/Contents/MacOS/DoxaSetup'

hdiutil verify "$DMG" >/dev/null
[[ -s "$DIST/SHA256SUMS.txt" ]]
(
  cd "$DIST"
  shasum -a 256 -c SHA256SUMS.txt
)
[[ -s "$DIST/SOURCE-COMMIT.txt" ]]

# Check that app packaging includes only our executable and metadata.
if find "$EXPANDED/package" -iname '*InstantView*' | grep -q .; then
  echo 'Third-party InstantView included unexpectedly.' >&2
  exit 1
fi
echo "MACOS_PACKAGE_CONTRACT_PASS"

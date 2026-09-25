#!/usr/bin/env bash
# Builds a Developer ID signed, notarized and stapled WrangURL.app and DMG in build/release.
#
# One-time setup:
#   1. Create a "Developer ID Application" certificate (Xcode → Settings → Accounts →
#      Manage Certificates, or developer.apple.com) and install it in your keychain.
#   2. Store notarization credentials (use an app-specific password from account.apple.com):
#        xcrun notarytool store-credentials WrangURL --apple-id <email> --team-id RCZ39FHJ3H
#
# Usage: scripts/release.sh
#   TEAM_ID         Apple Developer team (default: RCZ39FHJ3H)
#   NOTARY_PROFILE  notarytool keychain profile (default: WrangURL)
#   SKIP_NOTARIZE=1 build and sign only, e.g. to check signing before notarizing
set -euo pipefail

TEAM_ID="${TEAM_ID:-RCZ39FHJ3H}"
NOTARY_PROFILE="${NOTARY_PROFILE:-WrangURL}"
SIGNING_IDENTITY="Developer ID Application"

cd "$(dirname "$0")/.."
OUT="build/release"
ARCHIVE="$OUT/WrangURL.xcarchive"
APP="$OUT/export/WrangURL.app"

step() { printf '\n==> %s\n' "$*"; }

if ! security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
    echo "error: no \"$SIGNING_IDENTITY\" certificate in the keychain (see setup at the top of this script)" >&2
    exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"

step "Generating Xcode project"
xcodegen generate --quiet

step "Archiving"
xcodebuild archive -quiet \
    -project WrangURL.xcodeproj \
    -scheme WrangURL \
    -configuration Release \
    -archivePath "$ARCHIVE" \
    -skipPackagePluginValidation \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    OTHER_CODE_SIGN_FLAGS="--timestamp"

step "Exporting"
EXPORT_OPTIONS="$OUT/ExportOptions.plist"
cp scripts/ExportOptions.plist "$EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c "Add :teamID string $TEAM_ID" "$EXPORT_OPTIONS"
xcodebuild -exportArchive -quiet \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$OUT/export"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$OUT/WrangURL-$VERSION.dmg"

step "Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q get-task-allow \
    && { echo "error: release build has the get-task-allow entitlement" >&2; exit 1; }

if [[ "${SKIP_NOTARIZE:-}" == 1 ]]; then
    step "Skipping notarization; signed app at $APP"
    exit 0
fi

step "Notarizing app"
ditto -c -k --keepParent "$APP" "$OUT/WrangURL.zip"
xcrun notarytool submit "$OUT/WrangURL.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
rm "$OUT/WrangURL.zip"

step "Building DMG"
STAGING="$OUT/dmg"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "WrangURL" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"
codesign --sign "$SIGNING_IDENTITY" --timestamp "$DMG"

step "Notarizing DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

step "Checking Gatekeeper"
spctl --assess --type execute --verbose "$APP"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"

step "Done: $DMG"

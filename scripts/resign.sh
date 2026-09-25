#!/usr/bin/env bash
# Re-signs a built WrangURL.app with a self-signed code-signing identity.
#
# Ad-hoc signatures change with every build, so macOS treats each release as a different
# app (for example when it guards the sandbox container). A self-signed certificate gives
# every release the same designated requirement. Xcode refuses untrusted identities, so
# the app is built ad-hoc and re-signed here, innermost code first (no --deep, per Sparkle).
#
# Usage: scripts/resign.sh <path/to/WrangURL.app> <identity>
#   identity  certificate name or SHA-1 hash, e.g. "WrangURL Self-Signed". Its keychain must be
#             in the search list; codesign's --keychain option alone doesn't find it.
set -euo pipefail

APP="$1"
IDENTITY="$2"

sign() {
    codesign --force --sign "$IDENTITY" --options runtime --timestamp=none "$@"
}

SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE" ]]; then
    sign "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
    sign --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
    sign "$SPARKLE/Versions/B/Autoupdate"
    sign "$SPARKLE/Versions/B/Updater.app"
    sign "$SPARKLE"
fi

# Keep the entitlements and flags Xcode signed with, but not the designated requirement,
# which for an ad-hoc build is tied to its hash.
sign --preserve-metadata=entitlements,flags "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d -r- "$APP" 2>&1 | grep designated

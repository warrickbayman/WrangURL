---
paths:
  - "project.yml"
  - "scripts/**"
  - ".github/**"
  - "CHANGELOG.md"
  - "docs/**"
  - "README.md"
---

# Project, release and docs

- `project.yml` is the source of truth for build settings, `Info.plist` and entitlements. Never edit `WrangURL/Info.plist`, `WrangURL/WrangURL.entitlements` or `WrangURL.xcodeproj` directly. Run `xcodegen generate` after changing it or adding/removing files.
- Each entitlement and unusual build setting in `project.yml` has a comment explaining why it's there. Keep that up for new ones. Keep entitlements minimal: the app is sandboxed, and any new exception needs a concrete reason.
- Don't change `SUFeedURL`, `SUPublicEDKey`, the Sparkle mach-lookup exceptions, `CODE_SIGN_INJECT_BASE_ENTITLEMENTS` or the signing flow in `scripts/resign.sh`/`scripts/release.sh` unless asked. Mistakes there break auto-updates for existing users, and a release can't fix that.
- `CHANGELOG.md` sections are added by `.github/workflows/changelog.yml` on release. Don't add release sections by hand. Only reword existing entries when asked.
- CI runs on `macos-26` (the `NSGlassEffectView` SDK). Workflows keep `xcodebuild`'s exit status when piping through `grep`.
- `docs/` is a static GitHub Pages site (plain HTML/CSS/JS, no build step). Keep it dependency-free. Screenshots in `docs/images/` come in light and dark variants, captured with the demo data in `docs/demo/` using the steps in its README.
- The README and site describe behaviour to users. Update them whenever a user-visible feature changes.

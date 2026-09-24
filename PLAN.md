# WrangURL — Implementation Plan

A macOS menubar app, written in Swift, that routes URLs to specific browsers based on user-defined rules.

**Target:** macOS 14+ · Swift 6 · SwiftUI (with AppKit where needed) · Distributed outside the Mac App Store (Developer ID).

## Requirements

1. Menubar application named **WrangURL**.
2. Users define which URLs (simple patterns like `http://localhost`, or regex) open in which installed browsers.
3. A rule can target one or more browsers:
   - One browser → the URL opens in it directly.
   - Multiple browsers → the user is shown a picker.
4. WrangURL is set as the system default browser so it captures links opened from any app.
5. Optional launch at login.
6. When no rule matches, the user chooses (in settings) whether to open the **fallback browser** or show the **browser picker**.

## 1. Architecture

```
WrangURL.app  (SwiftUI App lifecycle + AppDelegate adaptor, LSUIElement = YES)
├── App/
│   ├── WrangURLApp.swift        MenuBarExtra + Settings/Onboarding window scenes
│   └── AppDelegate.swift        receives opened URLs (application(_:open:))
├── Core/
│   ├── Rule.swift               Codable model
│   ├── Settings.swift           Codable app settings (fallback, unmatched behavior)
│   ├── RuleMatcher.swift        simple + regex matching (pure, unit-tested)
│   ├── URLRouter.swift          URL → match → open, or show picker
│   ├── BrowserRegistry.swift    discovers installed browsers, icons, names
│   ├── DefaultBrowserManager.swift
│   ├── LoginItemManager.swift   SMAppService wrapper
│   └── ConfigStore.swift        JSON persistence in Application Support
├── UI/
│   ├── MenuBarView.swift
│   ├── Settings/                GeneralView, RulesView, RuleEditorView
│   ├── Onboarding/
│   └── Picker/                  BrowserPickerPanel (NSPanel hosting SwiftUI)
└── WrangURLTests/               matcher + router tests
```

## 2. Menubar app

- `MenuBarExtra` scene. The menu contains:
  - A status line: "✓ Default browser" or "⚠ Set as default browser…"
  - The current fallback browser
  - Rules…, Settings…
  - A "Launch at login" toggle
  - Quit
- `LSUIElement = YES` in Info.plist: no Dock icon and no app menu.
- Settings open in a SwiftUI `Window` scene. Call `NSApp.activate()` first, because accessory apps don't reliably come to the front without it.

## 3. Rules & matching

```swift
struct Rule: Codable, Identifiable {
    var id: UUID
    var name: String
    var pattern: String
    var kind: Kind              // .simple, .regex
    var browserIDs: [String]    // bundle identifiers, ordered
    var isEnabled: Bool
}
```

### Simple patterns

| Pattern              | Matches                                             |
|----------------------|-----------------------------------------------------|
| `localhost`          | host is `localhost`, any scheme or port             |
| `http://localhost`   | URL starts with `http://localhost` (any port/path)  |
| `*.example.com`      | `example.com` and any of its subdomains             |
| `github.com/myorg/*` | host plus a path prefix; `*` is a wildcard          |

- If the pattern has no scheme, it matches both `http` and `https`.
- Host matching is case-insensitive.
- Simple patterns are compiled internally to anchored regexes, so there is a single matching engine.

### Regex patterns

- Matched with `NSRegularExpression` against the full absolute URL string.
- Validated when the rule is saved, with the error shown inline in the editor.

### Evaluation

- Rules are evaluated in order and the first enabled match wins.
- Users reorder rules by dragging them in the list.
- If no rule matches, the behavior comes from the unmatched-URL setting (see §4).

### Rule editor

- A **"Test a URL"** field shows, live, which rule matches and which browser(s) would be used. It also shows the unmatched behavior when nothing matches.

## 4. Settings

```swift
struct AppSettings: Codable {
    var fallbackBrowserID: String          // bundle identifier
    var unmatchedBehavior: UnmatchedBehavior
}

enum UnmatchedBehavior: String, Codable {
    case openFallback   // open in fallback browser (default)
    case showPicker     // show picker with all installed browsers
}
```

- **General settings pane:**
  - The fallback browser (a popup menu of installed browsers).
  - "When no rule matches:" with two options: *Open in fallback browser* or *Ask me which browser to use*.
- If the unmatched behavior is `showPicker`, the picker lists **all** installed browsers, with the fallback browser first and preselected.
- The fallback browser is always required, even when the picker is used for unmatched URLs. It is used for:
  - local `.html` files,
  - a rule that points at a browser that has since been uninstalled,
  - Return in the picker for unmatched URLs.

## 5. Browser selection & picker

- **Discovery:** `NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "https://example.com")!)`.
  - Exclude WrangURL's own bundle ID.
  - Read the display name and icon from each app bundle.
  - Refresh the list when settings open, so newly installed browsers appear.
- **Opening:** `NSWorkspace.shared.open([url], withApplicationAt: browserURL, configuration:)`.
- **Single browser:** open immediately, with no UI.
- **Multiple browsers, or an unmatched URL with `showPicker`:** show a borderless floating `NSPanel` near the mouse cursor.
  - It shows browser icons in the rule's order.
  - Keys `1`–`9` select a browser, `Return` picks the first, and `Esc` cancels.
  - It includes a "Copy URL" action.
  - The URL is displayed, truncated, so the user knows what they're opening.
- **Loop guard:** WrangURL never opens a URL with itself. If a target browser is missing, the URL goes to the fallback browser instead.

## 6. Becoming the default browser

- **Info.plist.** Both entries are required for macOS to list the app as a browser:
  - `CFBundleURLTypes` for the `http` and `https` schemes.
  - `CFBundleDocumentTypes` for `public.html` and `public.xhtml`, with role `Viewer`.
- **Check the current default:** `NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://")!)`. Check it on launch and whenever the menu opens.
- **Set as default:** call `NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme:)` for `http` and `https`. macOS shows its own confirmation dialog, which can't be bypassed.
- **Receiving URLs:** in `AppDelegate`, implement `application(_:open urls: [URL])`.
  - On a cold start, macOS launches the app to deliver the URL. `URLRouter` must queue incoming URLs until the config has loaded.
  - Local `.html` files are passed to the fallback browser.

## 7. Launch at login

- Use `SMAppService.mainApp.register()` / `.unregister()`. No helper app is needed.
- Read `SMAppService.mainApp.status` rather than storing a flag, because users can turn it off in System Settings → Login Items.
- On `.requiresApproval`, call `SMAppService.openSystemSettingsLoginItems()`.

## 8. Persistence

- All rules and settings are stored in `Application Support/WrangURL/config.json`, which is human-readable and easy to back up. Because the app is sandboxed, the real path is `~/Library/Containers/com.thepublicgood.wrangurl/Data/Library/Application Support/WrangURL/config.json`.
- A config file that can't be read is renamed to `config.corrupt-<timestamp>.json`, so it is never silently overwritten.
- Import and export will need the `com.apple.security.files.user-selected.read-write` entitlement.
- Settings has Import and Export, for moving configs between machines.

## 9. First-run onboarding

1. **Choose a fallback browser.** The current system default is preselected; capture it *before* WrangURL takes over.
2. **Choose the unmatched-URL behavior:** fallback browser or picker.
3. **Set WrangURL as the default browser.**
4. **Enable launch at login** (optional).

## 10. Distribution & signing

- Developer ID signing, hardened runtime, and notarization. No Mac App Store.
- The App Sandbox isn't required. Try running with it enabled during the spike (milestone 1), and turn it off if it blocks any of these:
  - opening URLs in other apps (**verified working in the sandbox**, including cold launch),
  - setting the default browser (not yet verified; it needs the user to confirm the system dialog),
  - `SMAppService`.

## Notes from the spike

- `urlsForApplications(toOpen:)` also returns non-user browsers, such as Playwright's "Google Chrome for Testing" in `~/Library/Caches`. `BrowserRegistry` should hide apps outside `/Applications`, `~/Applications` and system locations, or let users hide them.
- Settings uses an AppKit window (`NSTabViewController` with toolbar tabs) hosting SwiftUI views, not a SwiftUI `Settings` scene. A menubar-only app can't reliably open that scene from outside a view: `showSettingsWindow:` no longer works, and `openSettings` is only available inside views.
- While Settings is open, the app switches to the `.regular` activation policy, so it gets a Dock icon and a place in ⌘-Tab. It switches back to `.accessory` when the window closes.
- The sandbox can't read app bundles in the home folder, so the entitlements include a read-only exception for `~/Applications`, where some users install browsers. The default-browser check also compares the app's path, because the sandbox can't read an Xcode build in `~/Library/Developer`.
- Debug builds accept these launch arguments, which open screens directly for UI work:
  - `-DebugSettingsTab <general|rules>` opens Settings on that tab.
  - `-DebugEditRule <index>` opens the rule editor.
  - `-DebugInsertionIndex <n>` draws the browser drop line at that position.
  - `-DebugOnboardingStep <0-3>` opens the setup assistant on that step.
  - `-DebugShowPicker <bundle IDs>` shows the picker with those browsers (comma-separated). `-DebugPickerURL <url>` sets the link it displays. Choosing a browser does nothing.
- When the app is hosting the unit tests (`XCTestConfigurationFilePath` is set), it skips startup side effects: it doesn't record the fallback browser or open the setup assistant.
- Setup is marked complete when its window closes by any means, so it doesn't reappear on every launch. Settings → General → Run Setup Again… reopens it.
- There's no notification when the default browser changes, so WrangURL re-checks whenever the user switches apps. The menubar icon shows a warning while WrangURL isn't the default.
- **Releasing:** `scripts/release.sh` archives with Developer ID signing, notarizes and staples the app, then builds, signs, notarizes and staples a DMG in `build/release/`.
  - One-time setup: install a Developer ID Application certificate, then run `xcrun notarytool store-credentials WrangURL --apple-id <email> --team-id RCZ39FHJ3H`.
  - `SKIP_NOTARIZE=1` builds and signs only.
  - The Release configuration sets `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO` so the `get-task-allow` entitlement isn't included. Notarization rejects it, and the script checks for it.
- **App icon:** generated by `scripts/make-app-icon.swift` into `Assets.xcassets/AppIcon.appiconset`. The menubar icon stays the `arrow.triangle.branch` SF Symbol, which macOS already draws as a template.
- **Import:** only accepts JSON with a `rules` or `settings` key, so an arbitrary file can't wipe the configuration. It offers Add Rules, which keeps your settings and gives duplicate IDs new ones, or Replace All, which keeps the "setup done" flag.
- In zsh, `log` is a shell builtin, so use `/usr/bin/log stream --predicate 'subsystem == "com.thepublicgood.wrangurl"'` to view the app's logs.
- Sparkle for auto-updates can be added later.

## 11. Milestones

1. ✅ **Spike (½ day).** A bare app with the Info.plist URL types that:
   - becomes the default browser,
   - logs received URLs,
   - forwards them to Safari.

   This proves the capture loop, including cold launch, before any UI work.
2. ✅ **Core.** `Rule`, `AppSettings`, `RuleMatcher`, `ConfigStore` and `BrowserRegistry`, with unit tests covering:
   - ports,
   - subdomains,
   - wildcards,
   - scheme-less patterns,
   - invalid regexes.
3. ✅ **Router.** Single-browser routing, fallback, unmatched behavior, and the cold-launch queue.
4. ✅ **Picker panel.** Multi-browser choice with keyboard shortcuts, reused for unmatched URLs.
5. ✅ **Menubar & Settings UI.**
   - General pane, including the fallback browser and unmatched behavior.
   - Rules list with reordering.
   - Rule editor with the URL tester.
6. ✅ **Default browser & login item management,** plus onboarding.
7. 🟡 **Polish.** Import/export, app icon and menubar icon are done. The notarized build is scripted but blocked until there's a Developer ID Application certificate.

## 12. Future ideas

- Hold ⌥ while clicking a link to force the picker.
- Rules based on the source app (e.g. "links from Slack → Chrome"). The sender's process ID is available from the incoming Apple Event.
- Browser profiles, such as Chrome or Edge profiles, launched with command-line arguments.
- A "Remember this choice" option in the picker that creates a rule automatically.
- Stripping tracking parameters (`utm_*`) before opening.

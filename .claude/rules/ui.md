---
paths:
  - "WrangURL/UI/**/*.swift"
  - "WrangURL/App/**/*.swift"
---

# UI (SwiftUI inside AppKit windows)

- Views get shared objects with `@Environment(Type.self) private var name`. A new shared object must be created in `AppDelegate.init` **and** added to `View.appEnvironment(_:)`, or views in some windows will crash on a missing environment object.
- Settings bindings read `config.config…` and write via `config.update { $0… = newValue }`. Don't keep a copy of config in `@State`. `@State` is only for transient view state, and is `private` (lint enforces this).
- New windows follow the existing pattern: an AppKit controller hosting SwiftUI through a `makeContent` closure set in `AppDelegate`, and registering with `ManagedWindow`/`DockPresence` so the Dock icon and activation policy stay correct. Don't add SwiftUI `Window`/`Settings` scenes.
- Don't touch the picker's window shape: `PickerPanel` stays a non-activating panel with a masked `NSVisualEffectView` (plus `NSGlassEffectView` on macOS 26). Keyboard handling goes through `PickerAction` (pure and tested), not ad-hoc key checks in views.
- Use native macOS controls and layouts: `Form`/`Section`/`LabeledContent`, `.pickerStyle(.radioGroup)`, SF Symbols, semantic colours (`.secondary`, `.orange` for warnings, `.green` for OK). Section footers are `.font(.caption).foregroundStyle(.secondary)`.
- Copy: buttons and menu items in Title Case, with "…" when they open more UI ("Set as Default Browser…"). Labels, toggles and explanations are sentence case in plain, friendly language. Use real key symbols (⌥⌘) for shortcuts.
- A new screen or state worth checking visually gets a `#if DEBUG` launch argument (`-Debug…`) in `AppDelegate`, and a line in CLAUDE.md's list, so it can be opened and screenshotted without clicking.
- Check UI changes in both light and dark appearance (`-DebugAppearance light|dark`).

---
paths:
  - "WrangURL/Core/Config.swift"
  - "WrangURL/Core/Rule.swift"
  - "WrangURL/Core/SourceApp.swift"
  - "WrangURL/Core/ModifierKeys.swift"
  - "WrangURL/Core/HistoryEntry.swift"
  - "WrangURL/Core/ConfigStore.swift"
  - "WrangURL/Core/ConfigImport.swift"
  - "WrangURL/Core/HistoryStore.swift"
---

# Persistence

The user's `config.json` and `history.json` must survive every upgrade and hand edit.

- Adding a stored property to a `Codable` model means adding it to the hand-written `init(from:)` too, using `decodeIfPresent(…) ?? <default>`, where the default equals the property's declared default. Add an assertion for it to `ConfigStoreTests.missingKeysUseDefaults` (or the history equivalent).
- Never rename or remove a coding key, and never change an enum's raw value. Add new ones instead.
- Only bump `Config.currentVersion` with an explicit migration and tests for it.
- `Config.decodeForImport` stays stricter than the normal decoder. An import must not be able to wipe the rules (e.g. by importing `{}`).
- Write with `.atomic`. Config is written with `[.prettyPrinted, .sortedKeys]`, so hand edits and diffs stay readable. Dates are ISO 8601.
- Rename an unreadable file aside (`config.corrupt-<timestamp>.json`). Never overwrite it or delete it.
- Change config only through `ConfigStore.update { }`. It skips no-op writes and saves immediately.
- Store types take their file URL in `init(fileURL:)`, so tests can point them at a temporary directory.

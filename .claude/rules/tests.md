---
paths:
  - "WrangURLTests/**/*.swift"
---

# Tests

- Swift Testing only (`import Testing`, `@testable import WrangURL`), no XCTest. Suites are `struct`s named `<Subject>Tests`. Each test is `@Test func` with a name that reads as a sentence about the behaviour (`uninstalledAndDuplicateBrowsersAreDropped`).
- Use `#expect` for assertions and `try #require` to unwrap. Group related cases in a suite with `// MARK:` sections.
- Build fixtures with small private helpers and constants in the suite (see `RoutePlannerTests.planner(…)`, `rule(_:)`) rather than repeating setup.
- Tests are hosted in the app, but `AppDelegate`'s objects are not set up for them. Build the object under test directly, and never read or write the real `config.json`/`history.json`: pass a URL under `FileManager.default.temporaryDirectory.appending(path: "WrangURLTests-\(UUID().uuidString)")`.
- Test pure types (`RoutePlanner`, `RuleMatcher`, `PickerAction`, `ModifierKeys`, config import/decoding) exhaustively. Don't try to unit-test AppKit windows. Use the `-Debug…` launch arguments for those instead.
- Filter `com.apple.linkd.autoShortcut` noise out of test output, and report real failures as they are.

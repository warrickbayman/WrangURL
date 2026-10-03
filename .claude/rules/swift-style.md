---
paths:
  - "WrangURL/**/*.swift"
  - "WrangURLTests/**/*.swift"
---

# Swift conventions

- Swift 6 with strict concurrency, deployment target macOS 14. Anything newer (e.g. `NSGlassEffectView`) goes behind `if #available(macOS 26, *)` with a working fallback.
- SwiftLint runs on every build and builds must stay warning-free. Lines go up to 140 characters. `implicit_return` is on, so leave out `return` in single-expression bodies. Use trailing commas in multi-line literals.
- Doc comments (`///`) are short, complete sentences that say *why* or what the caller has to know, not a restatement of the name. Inline `//` comments explain platform quirks and non-obvious decisions. Leave out comments that only narrate the code.
- Prefer modern Foundation: `.now`, `URL.appending(path:)`, `URL(filePath:)`, `formatted(.list(type: .or))`, key paths such as `map(\.id)`.
- Force-unwrapping is only OK for literal URLs (`URL(string: "https://…")!`) and in tests. Everywhere else use `guard`/`if let`, or `try #require` in tests.
- Name browsers and apps by bundle identifier `String`s (`browserID`, `browserIDs`). Resolve them to display objects through `BrowserRegistry.resolve(_:)` at the edge.
- Model types are value types: `struct`, `Codable`, `Equatable`/`Hashable`, `Sendable`.

## Logging

- One `Logger` per type: `private static let logger = Logger(subsystem: "com.thepublicgood.wrangurl", category: "<area>")`. Mark it `nonisolated` when the type is `@MainActor`.
- Interpolations are `privacy: .public`, **except URLs**, which always go through `URLRouter.loggable(_:)` (or an equivalent that checks `settings.logsURLs`). The "Include URLs in logs" setting must hold everywhere.
- Levels: `info` for routing decisions, `error` for failures, `fault` for "should never happen" (e.g. the loop guard).
- Stores and managers log I/O failures and carry on with a safe default. They don't throw into the UI.

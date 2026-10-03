---
paths:
  - "WrangURL/Core/**/*.swift"
---

# Core logic

- `RoutePlanner`, `RuleMatcher`, `SimplePattern`, `ModifierKeys`, `ConfigImport`, `Array+Move`, `URL+UserInput` and the models import only `Foundation`. Keep them that way. When new logic needs AppKit input, add a small AppKit adapter in a separate file (like `ModifierKeys+AppKit.swift`, `SourceApp+AppleEvent.swift`) and pass plain values into the pure type.
- Inject anything that touches the system as a closure or value, not a call inside the logic: `RoutePlanner.isAvailable`, `ModifierKeys.forLink(heldNow:lastClick:now:)` taking `now`. That keeps tests deterministic.
- Every routing or matching behaviour change comes with tests in `RoutePlannerTests` / `RuleMatcherTests` that pin down the new semantics. The Settings URL tester uses `URLRouter.preview(_:)`, so never route through a separate code path.
- There is only one matching engine: simple patterns compile to an anchored, case-insensitive regex over `url.absoluteString`. Don't add a second matcher.
- Long-lived services are `@MainActor @Observable final class`. Mark state the UI doesn't observe (dependencies, caches, queues) `@ObservationIgnored`, expose observable state as `private(set) var`, and make static helpers that do I/O `nonisolated static` so tests can call them directly.
- Never open a URL with WrangURL's own bundle, and never treat WrangURL as an available browser.

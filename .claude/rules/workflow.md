# Working in this repo

- Before any manual run that could change rules, back up `~/Library/Containers/com.thepublicgood.wrangurl/Data/Library/Application Support/WrangURL/config.json` (and `history.json`), and restore them afterwards. The debug build shares them with the installed app.
- Finish a change with a clean build (no SwiftLint warnings) and a passing `xcodebuild … test`, using the commands in CLAUDE.md.
- Commit messages are one imperative sentence ending in a full stop, describing the user-visible effect ("Hold ⌥⌘ while clicking a link to always show the browser picker."). Work happens on `feature/<topic>` branches merged by pull request, and PR titles become changelog entries, so write them for users.
- When a change adds a platform quirk or design decision, record it in PLAN.md's "Notes from the spike" or in CLAUDE.md, not only in a commit message.

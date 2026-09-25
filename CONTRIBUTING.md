# Contributing to WrangURL

Thanks for your interest in improving WrangURL. Bug reports, feature ideas and pull requests are all welcome.

## Reporting bugs and suggesting features

Open an [issue](https://github.com/warrickbayman/WrangURL/issues). For a bug, include:

- your macOS version and WrangURL version (shown in the About panel)
- the URL or pattern involved, and which browser you expected to open
- the relevant rules from `config.json`, or an exported configuration (**Settings → General → Export…**). Remove or change anything private first.

Logs often help. Make sure **Settings → General → Include URLs in logs** is on, then collect them with:

```sh
/usr/bin/log stream --level info --predicate 'subsystem == "com.thepublicgood.wrangurl"'
```

For a larger change, open an issue to discuss it before you start, so your work doesn't clash with other plans.

## Setting up

Follow [Building](README.md#building) in the README. In short, install Xcode 26 or later and XcodeGen, then:

```sh
xcodegen generate
open WrangURL.xcodeproj
```

The Xcode project, `WrangURL/Info.plist` and `WrangURL/WrangURL.entitlements` are all generated from `project.yml`. Edit `project.yml` instead of those files, and run `xcodegen generate` again after you change it or add or remove files.

A debug build shares its configuration with any installed copy of WrangURL. Back up `~/Library/Containers/com.thepublicgood.wrangurl/Data/Library/Application Support/WrangURL/config.json` before experimenting with rules, and restore it afterwards.

## Making changes

- **Keep routing logic testable.** `RoutePlanner`, `RuleMatcher`, `SimplePattern` and `PickerAction` don't depend on AppKit. Put new routing behaviour there and cover it with tests.
- **Keep old configuration files loading.** When you add a field to `Rule`, `AppSettings` or `Config`, also add it to that type's `init(from:)` with a default, using `decodeIfPresent`.
- **Don't write to real user files in tests.** Pass a file URL in instead, as with `ConfigStore(fileURL:)`.
- **Update the README** when you change something users can see.

[`CLAUDE.md`](CLAUDE.md) covers the architecture and the sandbox and signing quirks in more detail. [`PLAN.md`](PLAN.md) records the original design decisions.

### Linting

SwiftLint runs as part of every build, with its rules in `.swiftlint.yml`. Pull requests should build without lint warnings. If a rule really doesn't fit a particular line, silence it on that line with `// swiftlint:disable:next <rule>`, not for the whole file.

### Testing

Run the tests with **⌘U** in Xcode, or:

```sh
xcodebuild -project WrangURL.xcodeproj -scheme WrangURL -derivedDataPath build/DerivedData -skipPackagePluginValidation test
```

The tests use [Swift Testing](https://developer.apple.com/documentation/testing). The test output includes harmless `com.apple.linkd.autoShortcut` errors, which you can ignore.

For UI changes, debug builds accept launch arguments that open a particular screen straight away, such as `-DebugSettingsTab rules` or `-DebugShowPicker com.apple.Safari,com.google.Chrome`. The full list is in [`CLAUDE.md`](CLAUDE.md#testing-and-manual-ui-checks). Check your change in both light and dark mode, and include a screenshot in the pull request.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Keep each pull request to one change, and make sure the tests pass and the build has no warnings.
3. Write commit messages in the imperative mood, with a short subject line, for example "Add a copy button to the picker". Explain in the body what changed and why.
4. Open the pull request against `main` and describe what you changed and how you tested it.

The Tests workflow runs on every pull request. Releases are made by the maintainer, so don't change version numbers.

## AI-assisted contributions

WrangURL itself is built with Claude Code, so contributions made with AI tools are welcome. You're responsible for the result: read and understand the code you submit, and test it yourself.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE.md).

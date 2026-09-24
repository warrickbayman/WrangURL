# WrangURL

WrangURL is a macOS menu bar app that opens each link in the right browser. You write rules that match URLs, and WrangURL sends matching links to the browser you choose. If a rule lists more than one browser, a picker lets you choose each time.

<p align="center">
  <img src="docs/picker.png" alt="The WrangURL browser picker showing Safari, Google Chrome, Brave Browser and Zen for a localhost link" width="390">
</p>

- Match URLs with simple patterns like `localhost`, `*.example.com` or `github.com/myorg/*`, or with regular expressions.
- Send a match straight to one browser, or choose from a picker when a rule lists several.
- Choose what happens to links no rule matches: open them in a fallback browser, or show the picker.
- Runs in the menu bar and can open at login.

Requires macOS 14 or later.

## Usage

### First run

On first launch, a short setup assistant asks you to:

1. Choose a **fallback browser** for links that no rule matches.
2. Choose whether unmatched links open in the fallback browser or show the picker.
3. **Set WrangURL as your default browser.** WrangURL can only route links from other apps while it's the default. macOS asks you to confirm.
4. Optionally open WrangURL at login.

You can run the setup again from **Settings → General → Run Setup Again…**.

### Rules

Open **Edit Rules…** from the menu bar icon. Each rule has a pattern and one or more browsers. Rules are checked from top to bottom and the first match wins, so drag rules to reorder them.

**Simple patterns** match the host and, optionally, the scheme, port and path:

| Pattern | Matches |
|---|---|
| `localhost` | `localhost` over http or https, on any port |
| `http://localhost` | `localhost` over http only |
| `localhost:3000` | `localhost` on port 3000 only |
| `*.example.com` | `example.com` and all of its subdomains |
| `github.com/myorg/*` | URLs on `github.com` whose path starts with `/myorg/` |

Simple patterns ignore case. A path matches as a prefix, and `*` is a wildcard.

**Regular expressions** can match anywhere in the full URL. They're case-sensitive; start the pattern with `(?i)` to ignore case.

To check your rules, use **Test a URL** at the bottom of the Rules tab. It shows which rule matches and which browser would open. The rule editor has its own test field for the rule you're editing.

### The browser picker

The picker appears next to the mouse pointer. The app you clicked the link in stays in front.

| Key | Action |
|---|---|
| `1`–`9` | Open in that browser |
| `←` `→` or `Tab` | Move the selection |
| `Return` | Open in the selected browser |
| `⌘C` | Copy the link and close the picker |
| `Esc` or click elsewhere | Cancel |

### Settings and configuration

- **Settings → General** covers the fallback browser, what to do with unmatched links, launch at login, and the default browser status.
- If WrangURL stops being the default browser, the menu bar icon changes to ⚠︎.
- **Import… and Export…** save and load your rules and settings as JSON.
- Your configuration is stored in `~/Library/Containers/com.thepublicgood.wrangurl/Data/Library/Application Support/WrangURL/config.json`. After editing the file by hand, click **Reload** in Settings → General.

## Building

You'll need:

- Xcode 26 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), which generates the Xcode project from `project.yml`: `brew install xcodegen`

```sh
xcodegen generate
open WrangURL.xcodeproj
```

The generated `WrangURL.xcodeproj` isn't checked in. Run `xcodegen generate` again after adding or removing files, or after changing `project.yml`.

To build from the command line:

```sh
xcodebuild -project WrangURL.xcodeproj -scheme WrangURL -configuration Release -derivedDataPath build/DerivedData build
```

The app is written to `build/DerivedData/Build/Products/Release/WrangURL.app`. Debug and local builds are ad-hoc signed, so they run on your own Mac without a certificate.

When you set a development build as your default browser, macOS records the path of that particular copy. After moving or deleting it, set the default browser again.

### Releasing

`scripts/release.sh` builds a signed, notarized app and DMG in `build/release/`. It needs:

- A **Developer ID Application** certificate in your keychain.
- Notarization credentials saved once with:

  ```sh
  xcrun notarytool store-credentials WrangURL --apple-id <your Apple ID> --team-id <your team ID>
  ```

Set `SKIP_NOTARIZE=1` to build and sign without notarizing. There are more details at the top of the script.

## Testing

Run the tests from Xcode with **⌘U**, or from the command line:

```sh
xcodebuild -project WrangURL.xcodeproj -scheme WrangURL -derivedDataPath build/DerivedData test
```

The tests use Swift Testing. They cover:

- pattern matching
- routing decisions
- saving, loading and importing the configuration
- keyboard handling in the picker

While hosting the tests, the app skips its startup actions, so it doesn't open windows or change your configuration.

## License

WrangURL is released under the MIT License. See [LICENSE.md](LICENSE.md).

---

Copyright © 2026 Warrick Bayman.

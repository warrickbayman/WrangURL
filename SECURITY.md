# Security Policy

## Supported versions

Only the [latest release](https://github.com/warrickbayman/WrangURL/releases/latest) gets security fixes. WrangURL updates itself through Sparkle, so the fix for a vulnerability is a new release rather than a patch to an older version.

## Reporting a vulnerability

**Don't report security issues in public issues, discussions or pull requests.**

Report them privately through GitHub instead: go to the repository's [Security tab](https://github.com/warrickbayman/WrangURL/security) and choose **Report a vulnerability**. Only the maintainer can see the report.

Please include:

- the WrangURL and macOS versions affected
- a description of the problem and what an attacker could do with it
- steps to reproduce it, such as a URL, pattern or configuration file

WrangURL is maintained by one person in their spare time. You should get a reply within a week. Once a fix is released, the advisory is published and you're credited in it, unless you'd rather not be.

## Scope

WrangURL is the default browser, so it sees every link opened on the Mac. Issues worth reporting include:

- **Routing:** a crafted URL that opens in a browser other than the one the rules choose, bypasses the picker, or makes WrangURL open the URL itself or with an app that isn't a browser
- **Updates:** anything that gets an update installed without a valid EdDSA signature from the release key, or that weakens how the update feed is fetched
- **Configuration:** a configuration file that, when imported, does something other than change rules and settings, or crashes or hangs the app. For example, a regular expression rule that hangs the app when a link is opened.
- **Sandbox:** WrangURL reaching files, processes or services beyond what its entitlements in `project.yml` allow
- **Privacy:** URLs leaving your Mac. WrangURL only connects to the network to check GitHub for updates. It does record URLs in the local system log. Routed URLs are logged at info level, which macOS keeps only in memory by default. A URL that fails to open is logged as an error, which macOS saves to disk.

Outside the scope of this policy:

- vulnerabilities in the browsers WrangURL opens links in, which should be reported to their developers
- vulnerabilities in [Sparkle](https://github.com/sparkle-project/Sparkle/security) itself, unless WrangURL's use of it is the problem
- anything that needs an attacker to already control your user account, such as editing `config.json` directly
- releases being signed with a self-signed certificate instead of an Apple Developer ID. This is a known choice, and [the README](README.md) explains it.

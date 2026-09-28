# Screenshot demo data

`config.json` and `history.json` are the demo rules and history used for the screenshots in `docs/images/`. The rules use Google Chrome, Brave Browser, Safari and Zen, and the source apps Slack, Mail, Messages, Notes and Calendar. Install those apps first, or their icons show as placeholders.

The debug build shares its sandbox container with any installed copy of WrangURL, so back up your own files first. Quit WrangURL, then:

```sh
DATA=~/Library/Containers/com.thepublicgood.wrangurl/Data/Library/Application\ Support/WrangURL
mkdir -p /tmp/wrangurl-backup && cp "$DATA"/{config,history}.json /tmp/wrangurl-backup/
cp docs/demo/config.json "$DATA/config.json"

# Shift the history's dates so the newest entry is today, so the day headers read "Today" and "Yesterday".
python3 - "$DATA/history.json" <<'EOF'
import datetime as dt, json, sys
entries = json.load(open("docs/demo/history.json"))
parse = lambda s: dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
shift = dt.date.today() - parse(entries[0]["date"]).astimezone().date()
for entry in entries:
    entry["date"] = (parse(entry["date"]) + shift).strftime("%Y-%m-%dT%H:%M:%SZ")
json.dump(entries, open(sys.argv[1], "w"), indent=2)
EOF
```

Capture each screen from the debug build with the launch arguments in `CLAUDE.md`, once with `-DebugAppearance light` and once with `-DebugAppearance dark`. For example:

```sh
open build/DerivedData/Build/Products/Debug/WrangURL.app --args -DebugSettingsTab rules -DebugEditRule 1 -DebugAppearance light
```

The website's screenshots are 1x window captures that include the window shadow (`screencapture -l <window id>`).

Afterwards, quit the debug build and restore your files:

```sh
cp /tmp/wrangurl-backup/{config,history}.json "$DATA/"
```

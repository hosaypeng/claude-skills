---
name: kill-sync
description: "Kill and cleanly relaunch Sync.app to remove phantom windows from Mission Control. Use when Sync shows up in Mission Control despite being a menu-bar-only app."
---

# Kill Sync Skill

Restart Sync.app to eliminate phantom windows that cause it to appear in Mission Control.

## Execution

Run this command:

```bash
killall Sync 2>/dev/null && sleep 2 && open -a Sync --background
```

## Presentation

- IF Sync was running → report that it was restarted cleanly.
- IF Sync was not running (`killall` fails) → report that Sync wasn't running. Ask if the user wants to launch it.

## Troubleshooting

- **Sync still appears in Mission Control after kill**: The app may have relaunched itself before the `open` command. Run `killall Sync` again and wait longer before relaunching.
- **"No matching processes" error**: Sync.app isn't running. No action needed.

---
name: clean-caches
description: "Report and clear regenerable app caches (browser caches, uv, Homebrew, Zoom, Google Drive logs, the Claude desktop Cowork VM image) with the clean_caches command. Use when user says 'clean caches', 'clear cache', 'check for cache buildup', 'free up disk space', 'what's taking up space', or 'cache audit'."
user-invocable: true
argument-hint: "[report|run|scan] [--cowork]"
---

# Clean Caches

`/clean-caches` wraps the `clean_caches` command (`~/.local/bin/clean_caches`, symlinked from the private recovery repo's `bin/`). The command owns the target list and every safety check; this skill only runs it, looks for new buildup, and interprets the output.

## Steps

1. **Report (read-only):** `~/.local/bin/clean_caches`. Each known target gets a size and a status:
   - `ready`
   - `ready (quits Drive, relaunches it)`
   - `skip: quit <App> first`
   - `skip: locked by N uvx process(es)`
   - `skip: no rootfs.img.zst to rebuild from`
   - `opt-in: run --cowork`
   - `in-app: <where to clear it>`

   Items under 10M are left out.
2. **Scan for new buildup (read-only):** `~/.local/bin/clean_caches scan` lists the top dirs in `~/Library/Caches`, `~/.cache`, `~/Library/Application Support` and `~/Library/Containers`. Flag anything ≥ 500M that the report doesn't cover, and classify it as regenerable cache, app data or models.
   - Never call app data, models, chat stores, or an installed app's runtime "cache".
   - Check memory for known keep-lists before flagging anything.
3. **Present:**
   - free space
   - the ready total
   - each skipped item with its reason
   - numbered decisions for the user

   If the disk is under ~80% full, say nothing is urgent.
4. **Clear only after the user approves in chat:** `~/.local/bin/clean_caches run -y`. Add `--cowork` only if the user asked for the Cowork VM image.
   - Without `-y` the command refuses to run outside a terminal.
   - If an item is skipped because its app is running, ask the user to quit that app, then re-run. Never quit or kill apps yourself. The command itself quits and relaunches Google Drive.
5. **Report:**
   - the `freed` line, which is measured with `df` and is the real number. If other disk activity outweighed the gain, the line reads `no net gain measured` instead.
   - any `skipped: …`, `refused: …` or `failed: …` lines, verbatim. If Drive didn't quit, it is relaunched anyway when the command exits.

## Rules

- Never `rm` cache paths by hand, and never run `uv cache clean --force`.
- A new target goes into the command, never into an ad-hoc command. That means three changes: add it to `collect_items`, add its basename to the `safe_target` allowlist, and add a fake-HOME test case.
- Never clear `in-app` items. Give the user the in-app path instead.

## Notes

- **uv cache:** stays locked while any Claude Code session runs uvx-based MCP servers. Clear it from a plain terminal after quitting those sessions. Clearing it under running uvx servers deletes their environment files, so restart those sessions afterwards.
- **Cowork VM image:** the app rebuilds it from `rootfs.img.zst` the next time Cowork runs, so the space comes back.
- **Regrowth:** browser caches regrow within days, so the gain is temporary.
- **Sizes:** they are upper bounds (APFS clones share blocks), so the `freed` line is usually smaller than the ready total.

## Troubleshooting

- **`clean_caches: command not found`:** run `install.sh` in the recovery repo. Alternatively, `ln -s ~/Code/macos-recovery-setup/bin/clean_caches ~/.local/bin/clean_caches`.
- **Homebrew `failed:` followed by a `sudo chown` hint (a root-owned keg):** the user runs `! sudo chown -R $USER <keg path>`, then re-runs the command.
- **An item that always shows `skip: quit <App> first`:** the app is still running in the background. Ask the user to quit it fully (⌘Q, or from its menu-bar icon).

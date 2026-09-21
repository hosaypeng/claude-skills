---
user-invocable: true
name: cleanup
description: "Remove Claude session artifacts, system caches, project build artifacts, or forensic app traces. Use '/cleanup session' after Claude work, '/cleanup system' for disk space, '/cleanup purge' for stale node_modules/build dirs, '/cleanup forensic' for privacy, '/cleanup' to run all, '/cleanup history' to see what past runs trashed. Add '--dry-run' to any mode to preview without moving anything."
argument-hint: "[session|system|purge|forensic|all|history] [--dry-run]"
---

# Unified Cleanup Skill

You are executing the `/cleanup` skill. This skill consolidates session artifact cleanup, system cache cleanup, and forensic trace cleanup into a single command with modes.

## Command-line front end

`~/.local/bin/cleanup` (symlink to `bin/cleanup` in this skill) is the same engine usable without Claude Code: it dry-runs, prints a summary, asks, then runs. This skill calls it with `--yes` or `--dry-run` so the two paths never diverge.

```
cleanup [all|session|system|purge|forensic] [-n|--dry-run] [-y|--yes] [-v|--verbose] [-t N]
cleanup history [N] | preview | log [N] | whitelist | paths | status | help
```

If the symlink is missing: `ln -s ~/.claude/skills/cleanup/bin/cleanup ~/.local/bin/cleanup`.

## Argument Parsing

Parse the user's argument to determine the mode and flags:

| Argument | Mode | Command |
|----------|------|---------|
| `session` | Session artifacts only | `cleanup session --yes` |
| `system` | System caches only | `cleanup system --yes` |
| `purge` | Project build artifacts only | `cleanup purge --yes` |
| `forensic` | Forensic traces only | `cleanup forensic --yes` |
| `all` | All four in sequence | `cleanup all --yes` |
| `history [N]` | Show last N sessions + restore commands | `cleanup history N` |
| *(none)* | All four in sequence | `cleanup all --yes` |

**Flags:**

| Flag | Effect |
|------|--------|
| `--dry-run` | Replace `--yes` with `--dry-run`: every guard runs and every candidate is sized, but nothing moves. Writes `~/.claude/cleanup-preview.txt` (grouped by section, largest first) and a `.tsv` twin; `all` also keeps one preview per mode (`cleanup-preview-<mode>.{txt,tsv}`). |

The CLI runs the dry-run itself before the real run, so a plain `/cleanup system` already produces the preview and then executes. Pass `--verbose` to see the raw script output instead of the summary. The underlying scripts remain runnable directly: `CLEANUP_DRY_RUN=1 bash ~/.claude/skills/cleanup/scripts/cleanup_system.sh`.

**Script directory**: `~/.claude/skills/cleanup/scripts/`

## Execution

1. Determine the mode from the argument (default = `all`) and whether `--dry-run` is present.
2. Run `cleanup <mode> --yes` (or `cleanup <mode> --dry-run`). Without `--yes` the CLI would wait on a confirmation prompt that this non-interactive shell cannot answer.
3. Capture and present the output to the user.
4. Flag any item that recovered more than 500MB, any deletion that failed, and any report-only item exceeding 1GB.
5. IF any single item exceeds 1GB → highlight it and confirm with the user before the next run.
6. IF orphan candidates were reported → list them for the user and note that they were NOT deleted. Never delete them on the user's behalf without explicit confirmation of the specific paths.
7. IF dry-run → show the preview file path, the per-section totals, and the ten largest candidates. Offer the real run as the next step; do not run it unprompted.

## Whitelist

All modes respect `~/.claude/cleanup-whitelist.txt`. One glob pattern per line, `#` for comments, `~` expands to `$HOME`. A path is skipped when it:

- matches a pattern (`~/.venvs/foo`, `~/Library/Caches/com.example.*`), or
- is an **ancestor** of a whitelisted path — trashing `~/Library/Caches/Homebrew` would take a whitelisted `~/Library/Caches/Homebrew/downloads/keep.tgz` with it, so the parent is skipped too, or
- is a **descendant** of a literal (non-glob) whitelisted directory.

Example:

```
~/.ollama/models/*
~/.cache/huggingface*
~/Library/Caches/com.nssurge.surge-mac/*
```

## Protection List

`references/protected_patterns.txt` is a hard stop the whitelist cannot override: password managers, VPN/proxy clients, input methods, messaging cache roots, browser profiles, cloud-sync client state, endpoint-security sensors, AI-tool session state, and Apple caches whose removal breaks search, fonts, iCloud, or Vision (`com.apple.e5rt.e5bundlecache`). Every `safe_trash` call checks it; matches are logged as `SKIPPED (protected)`. Add a pattern there — not an inline `case` in a script — when an app keeps auth state or keys in a directory that looks like a cache.

## Safety Rules

1. **ALL deletions use `mv ~/.Trash/`** — never `rm -rf`. Every deletion is reversible, and `/cleanup history` prints the exact `mv` to restore anything still in the Trash.
2. **Review any deletion over 1GB** — scripts report sizes in output; highlight it to the user after running.
3. **SKIP any directory that doesn't exist.**
4. **PRESERVE files modified in the last 7 days** (in system cache mode).
5. **NEVER delete** user documents, app binaries, config files, keychains, or active files.
6. **NEVER recommend granting Full Disk Access to Terminal** — for TCC-protected files, recommend Finder deletion instead.
7. **Handle locked files gracefully** — report them, do not error out.
8. **Orphan detection NEVER deletes** — it reports candidates only. Bundle-ID matching cannot see CLI tools (no `.app` bundle), group containers (`EQHXZ8M8AV.group.com.google.drivefs` vs `com.google.drivefs`), or bare framework names (`PassKit`). It once deleted live data for Google Drive, WhatsApp, Zoom, and Shortcuts while all four were running. Present candidates to the user for manual Finder deletion.
9. **Report-only items** (Xcode Archives, CoreSimulator, Docker, iOS backups, login items, kexts, Trash, Time Machine, orphan candidates, non-allowlisted dotdirs, Claude Desktop bundled runtimes in `~/Library/Application Support/Claude/claude-code{,-vm}/` (no symlink names the active one), and expensive dev caches: `~/.cache/huggingface`, `~/.cargo/registry/src`, `~/.gradle/caches/modules-*`, `~/.m2/repository`, `~/.ivy2/cache`, `~/.nuget/packages`) are shown but never auto-deleted.
10. **Regenerable-by-construction items ARE auto-deleted** (to Trash) once idle: `~/Library/Application Support/Caches/*-updater` (>30d), `GoogleUpdater/crx_cache` contents (>7d) and GoogleUpdater version dirs other than the `Current` symlink target, `Saved Application State/*.savedState` (>30d), `~/.venvs/*` (>90d), and dotdirs on the `REGENERABLE_DOTDIRS` allowlist in `cleanup_system.sh` (>180d). Stale Claude Code native versions in `~/.local/share/claude/versions/` are trashed with **no idle threshold** — the active one is whatever `~/.local/bin/claude` resolves to, so anything else is superseded the moment the symlink moves; if the symlink is missing or points elsewhere, nothing is touched. The dotdir list is allow-by-name, never deny-by-default — add a tool's dotdir there only if it holds nothing but caches/session state.
11. **Running apps are never touched, and "unknown" counts as running.** `is_app_running` is tri-state (running / idle / unknown) and `cache_owner_running` matches a cache's bundle ID or directory name against the live process table: the full ID in any command line, the ID's leaf as an executable's exact basename (`com.apple.mediaanalysisd` → `mediaanalysisd`), or the leaf plus a vendor token on one line; generic leaves (`extension`, `intents`, `helper`, …) fall back to the previous component. A cache is only cleared when its owner is *conclusively* idle — a failed `pgrep`, an unreadable process table, or a plausible name match all mean skip.
12. **Trash reversibility assumes nothing else empties the Trash.** `mo clean` (Mole) empties `~/.Trash` permanently on every non-dry-run invocation, with no age guard. `~/.config/mole/whitelist` therefore lists `~/.Trash` — **alongside every one of Mole's own default patterns**, because a user whitelist *replaces* Mole's defaults rather than merging with them (a one-line file would silently strip Mole's protection of `~/.ollama/models` and iCloud `Mobile Documents`). If you edit that file, keep the defaults.
13. **Disk free space does not change** until the Trash is emptied — everything moves to `~/.Trash` on the same volume. Never present a `df` delta as space recovered.
14. **Sizing has a timeout.** `safe_size` gives `du` 10 seconds (`CLEANUP_SIZE_TIMEOUT` to change); a cloud placeholder folder that hangs `du` reports `size unknown` and the item is still handled. Unknown sizes are excluded from totals.

## Presentation

After running the script(s), present the user with:
1. A clear summary of what was cleaned per category (or *would be*, on a dry run)
2. Total disk space recovered (or previewed)
3. Report-only items that may need manual attention
4. Any items that could not be removed (with explanation)
5. Manual steps required for TCC-protected items (if applicable)
6. The per-item log location (`~/.claude/cleanup-operations.log`) and, on a dry run, the preview file path

## Logs

Every mode appends to one per-item operations log: `~/.claude/cleanup-operations.log` (rotates to `.old` at 5MB). Format:

```
# ==== system started at 2026-09-21 12:23:07 ====
[2026-09-21 12:23:08] [system] TRASHED /path -> /Users/hsp/.Trash/name.1789… (15MB)
[2026-09-21 12:23:08] [system] SKIPPED /path (protected|whitelisted|owner running or unknown|git-tracked|cloud-synced)
[2026-09-21 12:23:09] [system] FAILED /path (permission denied or locked)
[2026-09-21 12:23:09] [system] REPORTED /path (259MB, note)
# ==== system ended at 2026-09-21 12:23:45, 115 items, 1GB, skipped 5, failed 0 ====
```

Dry runs log `WOULD_TRASH` instead of `TRASHED`. `/cleanup history` parses this log. The older per-mode summary logs (`cleanup-log.txt`, `system-cleanup-log.txt`, `purge-projects-log.txt`, `purge-artifacts-log.txt`) are no longer written.

## Troubleshooting

- **"Permission denied" on cache files**: Some caches are locked by running apps. Quit the app and retry, or note it as a manual step.
- **TCC-protected databases (KnowledgeC, etc.)**: Terminal cannot access these without Full Disk Access. Do NOT grant FDA — instead tell the user to delete via Finder.
- **Trash fills up after cleanup**: This is by design — all deletions go to Trash. User empties Trash via Finder when ready.
- **Script reports 0KB recovered but items were found**: The items may have already been empty directories or permission-denied. Check stderr output for details.
- **"X running or unknown — skipping cache"** for an app that is not open: the process-table probe matched the app's name in some other process's command line. Conservative by design. Some matches are permanent — Pencil's bundled MCP server keeps `Pencil` resident whenever Claude Code has it configured — so that app's Application Support cache is never auto-cleaned; clear it by hand if it matters, or whitelist nothing and accept it.
- **Restoring something**: run `/cleanup history` and copy the printed `mv -n` line.

Execute the cleanup now based on the provided mode argument.

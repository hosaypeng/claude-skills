---
name: cleanup
description: "Remove Claude session artifacts, system caches, project build artifacts, or forensic app traces. Use '/cleanup session' after Claude work, '/cleanup system' for disk space, '/cleanup purge' for stale node_modules/build dirs, '/cleanup forensic' for privacy, or '/cleanup' to run all."
argument-hint: "[session|system|purge|forensic|all]"
---

# Unified Cleanup Skill

You are executing the `/cleanup` skill. This skill consolidates session artifact cleanup, system cache cleanup, and forensic trace cleanup into a single command with modes.

## Argument Parsing

Parse the user's argument to determine the mode:

| Argument | Mode | Script |
|----------|------|--------|
| `session` | Session artifacts only | `cleanup_session.sh` |
| `system` | System caches only | `cleanup_system.sh` |
| `purge` | Project build artifacts only | `cleanup_purge.sh` |
| `forensic` | Forensic traces only | `cleanup_forensic.sh` |
| `all` | All four in sequence | `cleanup_all.sh` |
| *(none)* | All four in sequence | `cleanup_all.sh` |

**Script directory**: `~/.claude/skills/cleanup/scripts/`

## Execution

1. Determine the mode from the argument (default = `all`)
2. Run the corresponding script from `~/.claude/skills/cleanup/scripts/`
3. Capture and present the output to the user
4. Analyze results and highlight important findings
5. IF any single item exceeds 1GB → highlight it and confirm with the user before the next run

## Mode Details

### Session Mode (`/cleanup session`)
Removes Claude-specific session artifacts:
- Scratchpad directories under `/private/tmp/claude-*`
- Debug logs older than 7 days (`~/.claude/debug/`)
- Claude desktop app cache (`~/Library/Application Support/Claude/Cache/`)
- Old VM bundles — keeps only the latest (`~/Library/Application Support/Claude/vm_bundles/`)
- Stale project caches older than 30 days (`~/.claude/projects/`)
- Old backup files older than 30 days (`~/.claude/backups/`)
- Session caches older than 30 days (file-history, image-cache, paste-cache)
- Orphaned Claude processes (detected but not killed automatically)
- Stale lock files in `/tmp/`
- Temporary/partial downloads

### System Mode (`/cleanup system`)
Frees disk space by clearing caches:
- User library caches (preserves files modified in last 7 days)
- Browser caches (Chrome, Safari, Firefox)
- Development caches: Homebrew, npm, pip, uv, Yarn, pnpm, Go, Cargo, Maven, Gradle, CocoaPods, Composer, Ruby Bundler, Xcode DerivedData
- Sandboxed app caches (`~/Library/Containers/*/Data/Library/Caches`)
- App-specific caches (Discord, VS Code, Slack, Zoom)
- Application Support logs and caches (scans all `~/Library/Application Support/*/` subdirs for Cache/Logs/GPUCache)
- Xcode Archives and CoreSimulator (reported, not auto-deleted)
- Docker disk usage (reported, not auto-deleted)
- iOS device backups (reported, not auto-deleted)
- System temp files and partial downloads
- Old logs (30+ days)
- Time Machine local snapshots (reported, not auto-deleted)
- Current Trash size (reported, never auto-emptied)

### Purge Mode (`/cleanup purge`)
Removes stale build artifacts from project directories:
- `node_modules`, `.next`, `target`, `.build`
- `__pycache__`, `.pytest_cache`, `.mypy_cache`, `.ruff_cache`, `.tox`
- `.venv`, `venv` (Python virtualenvs)
- `.gradle`, `.parcel-cache`, `.turbo`, `.angular`, `.nuxt`, `.svelte-kit`, `.expo`

Generic names (`build`, `dist`, `.output`, `coverage`) are excluded — too often git-tracked or intentional. Git-tracked directories are always skipped.

Only targets artifacts older than 30 days and larger than 1MB. Scan paths are configured in `~/.claude/cleanup-purge-paths.txt` (one directory per line). Defaults to `~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Code`, `~/Projects`, `~/Code`, `~/dev`, `~/GitHub`, `~/Repos`.

### Forensic Mode (`/cleanup forensic`)
Removes privacy-sensitive traces left by uninstalled apps:
- Quarantine events database (download history)
- KnowledgeC database (app usage history)
- CoreDuet database (interaction patterns)
- Recent items and Spotlight shortcuts
- Launch Services database rebuild
- Orphaned app data (saved state, group containers, HTTPStorages, Application Support)
- Orphaned containers (reported — SIP-protected, requires Finder to delete)
- Orphaned preferences (flagged for review — some belong to CLI tools)
- Orphaned LaunchAgents (background services referencing missing executables)
- Login items referencing deleted apps (reported for manual review)
- Third-party kernel extensions (reported, requires sudo)
- Crash reports and diagnostic logs
- Siri suggestions data

## Whitelist

All modes respect `~/.claude/cleanup-whitelist.txt`. Paths matching any pattern in this file are skipped. One glob pattern per line, `#` for comments. Example:

```
/Users/hsp/.ollama/models/*
/Users/hsp/.cache/huggingface*
/Users/hsp/Library/Caches/com.nssurge.surge-mac/*
```

## Safety Rules

1. **ALL deletions use `mv ~/.Trash/`** — never `rm -rf`. Every deletion is reversible.
2. **ASK user confirmation before deleting anything over 1GB** — the script reports it, the agent confirms.
3. **SKIP any directory that doesn't exist.**
4. **PRESERVE files modified in the last 7 days** (in system cache mode).
5. **NEVER delete** user documents, app binaries, config files, keychains, or active files.
6. **NEVER recommend granting Full Disk Access to Terminal** — for TCC-protected files, recommend Finder deletion instead.
7. **Handle locked files gracefully** — report them, do not error out.
8. **Deep orphan detection is mandatory** — always cross-reference against installed app bundle IDs before flagging as orphan.
9. **Report-only items** (Xcode Archives, CoreSimulator, Docker, iOS backups, login items, kexts, Trash, Time Machine) are shown but never auto-deleted.

## Presentation

After running the script(s), present the user with:
1. A clear summary of what was cleaned per category
2. Total disk space recovered
3. Report-only items that may need manual attention
4. Any items that could not be removed (with explanation)
5. Manual steps required for TCC-protected items (if applicable)

## Log Files

Each mode appends to its own log:
- Session: `~/.claude/cleanup-log.txt`
- System: `~/.claude/system-cleanup-log.txt`
- Purge: `~/.claude/purge-projects-log.txt`
- Forensic: `~/.claude/purge-artifacts-log.txt`

## Troubleshooting

- **"Permission denied" on cache files**: Some caches are locked by running apps. Quit the app and retry, or note it as a manual step.
- **TCC-protected databases (KnowledgeC, etc.)**: Terminal cannot access these without Full Disk Access. Do NOT grant FDA — instead tell the user to delete via Finder.
- **Trash fills up after cleanup**: This is by design — all deletions go to Trash. User empties Trash via Finder when ready.
- **Script reports 0KB recovered but items were found**: The items may have already been empty directories or permission-denied. Check stderr output for details.

Execute the cleanup now based on the provided mode argument.

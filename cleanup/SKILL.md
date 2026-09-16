---
user-invocable: true
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
4. Flag any item that recovered more than 500MB, any deletion that failed, and any report-only item exceeding 1GB.
5. IF any single item exceeds 1GB → highlight it and confirm with the user before the next run
6. IF orphan candidates were reported → list them for the user and note that they were NOT deleted. Never delete them on the user's behalf without explicit confirmation of the specific paths.

## Mode Details

See `~/.claude/skills/cleanup/references/modes.md` for detailed mode descriptions.

## Whitelist

All modes respect `~/.claude/cleanup-whitelist.txt`. Paths matching any pattern in this file are skipped — both whole directories and individual items inside a directory being cleared. One glob pattern per line, `#` for comments. Patterns are matched against the full expanded path, so include a trailing `/*` only when you mean the contents rather than the directory itself. Example:

```
~/.ollama/models/*
~/.cache/huggingface*
~/Library/Caches/com.nssurge.surge-mac/*
```

## Safety Rules

1. **ALL deletions use `mv ~/.Trash/`** — never `rm -rf`. Every deletion is reversible.
2. **Review any deletion over 1GB** — scripts report sizes in output; highlight it to the user after running. All deletions go to Trash and are fully reversible.
3. **SKIP any directory that doesn't exist.**
4. **PRESERVE files modified in the last 7 days** (in system cache mode).
5. **NEVER delete** user documents, app binaries, config files, keychains, or active files.
6. **NEVER recommend granting Full Disk Access to Terminal** — for TCC-protected files, recommend Finder deletion instead.
7. **Handle locked files gracefully** — report them, do not error out.
8. **Orphan detection NEVER deletes** — it reports candidates only. Bundle-ID matching cannot see CLI tools (no `.app` bundle), group containers (`EQHXZ8M8AV.group.com.google.drivefs` vs `com.google.drivefs`), or bare framework names (`PassKit`). It once deleted live data for Google Drive, WhatsApp, Zoom, and Shortcuts while all four were running. Present candidates to the user for manual Finder deletion.
9. **Report-only items** (Xcode Archives, CoreSimulator, Docker, iOS backups, login items, kexts, Trash, Time Machine, orphan candidates, and expensive dev caches: `~/.cache/huggingface`, `~/.cargo/registry`, `~/.m2/repository`, `~/.gradle/caches`) are shown but never auto-deleted.
10. **Disk free space does not change** until the Trash is emptied — everything moves to `~/.Trash` on the same volume. Never present a `df` delta as space recovered.

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

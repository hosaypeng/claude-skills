---
user-invocable: true
name: audit-icloud
description: "Audit all iCloud containers for files, artifacts, caches, and metadata. Scans every app container in ~/Library/Mobile Documents/. Use when user says 'audit icloud', 'check icloud', 'what's in my icloud', or 'icloud cleanup'."
argument-hint: "[full|summary|clean]"
---

# Audit iCloud

Parse the argument to determine which mode to run:

- **`full`** (or no argument) — full audit: artifacts, every container with its files, totals
- **`summary`** — container totals only, no per-file listings
- **`clean`** — run the audit, then offer to move any artifacts found to the Trash

## Execution

```bash
# full
bash ~/.claude/skills/audit-icloud/scripts/audit_icloud.sh

# summary
ICLOUD_AUDIT_SUMMARY=1 bash ~/.claude/skills/audit-icloud/scripts/audit_icloud.sh
```

The script never modifies anything and always exits 0 (1 only if `~/Library/Mobile Documents` is missing).

## What the script reports

- **Artifacts** — `[ARTIFACT] <path> (<size>)` for junk macOS scatters into synced folders: `.DS_Store`, `Thumbs.db`, `*.tmp`, `._*` resource forks, and the directories `.Spotlight-*`, `.Trashes`, `__MACOSX`, `.fseventsd`, `.TemporaryItems`. Artifacts are excluded from container file counts.
- **Containers** — `--- <container> (<n> files, <size>[, <n> not downloaded]) ---`. Containers with ≤50 files list each file; larger ones are grouped by top-level item, largest first. `.icloud` placeholders (files not downloaded to this Mac) are counted separately and never sized.
- **Summary** — total files, total size, not-downloaded count, containers with files, empty containers, artifact count and size.

The script already flags WhatsApp containers (`(encrypted WhatsApp backup — never modify)`) and does not list files in `iCloud~md~obsidian`.

## Presenting Results

1. **Artifacts table** (if any found):

| Type | Path | Size |
| ---- | ---- | ---- |

2. **Container summary table** (always shown):

| Container | Files | Size |
| --------- | ----: | ---- |

3. **Totals line**: total files, total size, containers with files, empty containers.

For **`full`** mode, also show the per-file / grouped listings the script printed.

For **`clean`** mode, after presenting results, ask the user which artifacts to move. Move confirmed items to `~/.Trash/` with `mv -n <path> ~/.Trash/` — never `find -delete` or `rm`. Skip anything inside a WhatsApp container.

## Important

- ALWAYS scan ALL of `~/Library/Mobile Documents/`, not just `com~apple~CloudDocs` — there are 100+ containers.
- Never move or delete files in `clean` mode without explicit user confirmation.
- WhatsApp backups are encrypted — flag them, never modify.
- `*.tmp` can match real files; show the full artifact list before any move.

## Troubleshooting

- **Permission denied**: iCloud Drive may be syncing. Wait and retry.
- **Output too large**: use `summary` mode.
- **Missing containers**: some containers only appear after their app has been opened at least once.

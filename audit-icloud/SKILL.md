---
user-invocable: true
name: audit-icloud
description: "Audit all iCloud containers for files, artifacts, caches, and metadata. Scans every app container in ~/Library/Mobile Documents/. Use when user says 'audit icloud', 'check icloud', 'what's in my icloud', or 'icloud cleanup'."
argument-hint: "[full|summary|clean]"
---

# Audit iCloud

Parse the argument to determine which mode to run:

- **`full`** (or no argument) — run the full audit script and present results
- **`summary`** — run the script but only show the summary table, skip per-file listings
- **`clean`** — run the audit, then offer to delete any artifacts found (.DS_Store, Thumbs.db, .tmp, ._* files)

## Execution

Run the audit script:

```bash
bash ~/.claude/skills/audit-icloud/scripts/audit_icloud.sh
```

## Presenting Results

After running the script, present results as:

1. **Artifacts table** (if any found):

| Type      | Path                  | Size |
| --------- | --------------------- | ---- |

2. **Container summary table** (always shown):

| Container         | Files | Size     | Description          |
| ----------------- | ----: | -------- | -------------------- |

3. **Totals line**: total files, total size, containers with files, empty containers.

For **`full`** mode, also list individual files per container (grouped for large containers like Apple Books).

For **`clean`** mode, after presenting results, ask the user which artifacts to delete. Move confirmed deletions to `~/.Trash/` (e.g., `mv -n artifact ~/.Trash/`) — never use `find -delete` or `rm`. Offer to clean up empty directories left behind (also move to Trash).

## Important

- ALWAYS scan ALL of `~/Library/Mobile Documents/`, not just `com~apple~CloudDocs`. There are 100+ iCloud containers for different apps.
- The Obsidian vault lives in `iCloud~md~obsidian` — include it in the summary but do not list individual vault files (use `/audit-vault` for that).
- Never delete files in `clean` mode without explicit user confirmation.
- WhatsApp backups are encrypted — flag them but never modify.

## Troubleshooting

- **Permission denied**: iCloud Drive may be syncing. Wait and retry.
- **Output too large**: The script groups large containers (50+ files) by top-level item. If still too large, use `summary` mode.
- **Missing containers**: Some containers only appear after their app has been opened at least once.

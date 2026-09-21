---
user-invocable: true
name: audit-icloud
description: "Audit all iCloud containers for files, artifacts, caches, and metadata. Scans every app container in ~/Library/Mobile Documents/. Use when user says 'audit icloud', 'check icloud', 'what's in my icloud', or 'icloud cleanup'."
argument-hint: "[full|summary|clean]"
---

# Audit iCloud

You are executing the `/audit-icloud` skill.

## Where the code lives

The engine is the `audit-icloud` CLI from **hosaypeng/audit-icloud** (`~/Code/audit-icloud`,
symlinked to `~/.local/bin/audit-icloud`). This skill is a thin client: it runs the CLI and
presents the result, so what Claude does and what the user does at a prompt share one code path.

```
audit-icloud [report] [-f|--full]
audit-icloud clean [-n|--dry-run] [-y|--yes]
audit-icloud help
```

IF `audit-icloud` is not on PATH → tell the user to run `~/Code/audit-icloud/install.sh` (or
clone `git@github.com:hosaypeng/audit-icloud.git` to `~/Code/audit-icloud` first). Do not
reimplement any of it here.

## Argument Parsing

| Argument | Command |
|----------|---------|
| *(none)* / `summary` | `audit-icloud` |
| `full` | `audit-icloud --full` |
| `clean` | `audit-icloud clean --dry-run`, present the list, **ask the user**, then `audit-icloud clean --yes` |

Without `--yes` the `clean` command waits on a confirmation prompt that this non-interactive
shell cannot answer, so the confirmation happens in chat instead: dry-run → show → ask → `--yes`.

## What the CLI reports

1. **Container table** sorted by size — `App | Container | Files | Size | Note`, with a Total
   row. Notes: `encrypted, never modify` (WhatsApp), `audited separately` (the Obsidian
   container), `<n> not downloaded` (`.icloud` placeholders, counted but never sized).
2. **Artifact table** — `Size | Kind | Path` (relative to the mirror) for `.DS_Store`,
   `Thumbs.db`, `*.tmp`, `._*`, and the directories `.Spotlight-*`, `.Trashes`, `__MACOSX`,
   `.fseventsd`, `.TemporaryItems`. `Artifacts  none` when clean.
3. **Per-container sections** (`full` only) — `<App>  <container id>  ·  <n> files, <size>` then
   `<size>  <path>` rows (≤50 files) or `<size>  <n> files  <top-level item>` rows grouped and
   sorted by size. WhatsApp and the Obsidian container have no section. Output is never
   truncated when piped, so you see full paths.

`clean` moves each artifact to `~/.Trash/<name>.<timestamp>` with `mv -n` and prints a restore
`mv` line per item. It skips anything inside a WhatsApp container. Nothing is ever `rm`'d.

## Presentation

The CLI output is already laid out for reading; relay it rather than re-tabulating it. Lead
with the header line and anything notable (large containers, artifacts, not-downloaded files).
For `clean`, after the real run show the moved items and their restore lines.

## Rules

- Never run `audit-icloud clean --yes` without the user confirming the dry-run list in chat.
- WhatsApp backups are encrypted — the CLI never touches them; do not work around that.
- `*.tmp` can match real files; call out any `.tmp` entry in the list before asking.
- Moves inside an iCloud container sync to every device; say so if the list is large.

## Troubleshooting

- **Permission denied**: iCloud Drive may be syncing. Wait and retry.
- **Output too large**: drop `full`; the default is the tables only.
- **Missing containers**: some containers only appear after their app has been opened once.
- **Restoring something**: paste the `restore: mv -n …` line the CLI printed.

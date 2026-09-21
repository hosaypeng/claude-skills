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
audit-icloud [report] [-s|--summary]
audit-icloud clean [-n|--dry-run] [-y|--yes]
audit-icloud help
```

IF `audit-icloud` is not on PATH → tell the user to run `~/Code/audit-icloud/install.sh` (or
clone `git@github.com:hosaypeng/audit-icloud.git` to `~/Code/audit-icloud` first). Do not
reimplement any of it here.

## Argument Parsing

| Argument | Command |
|----------|---------|
| *(none)* / `full` | `audit-icloud` |
| `summary` | `audit-icloud --summary` |
| `clean` | `audit-icloud clean --dry-run`, present the list, **ask the user**, then `audit-icloud clean --yes` |

Without `--yes` the `clean` command waits on a confirmation prompt that this non-interactive
shell cannot answer, so the confirmation happens in chat instead: dry-run → show → ask → `--yes`.

## What the CLI reports

- **Artifacts** — `[ARTIFACT] <path> (<size>)`: `.DS_Store`, `Thumbs.db`, `*.tmp`, `._*`, and the
  directories `.Spotlight-*`, `.Trashes`, `__MACOSX`, `.fseventsd`, `.TemporaryItems`.
- **Containers** — `--- <container> (<n> files, <size>[, <n> not downloaded]) ---`, then per-file
  rows (≤50 files) or rows grouped by top-level item, largest first. WhatsApp containers carry an
  `(encrypted WhatsApp backup — never modify)` note; `iCloud~md~obsidian` is counted but not listed.
- **Summary** — total files, total size, not-downloaded count, containers with files, empty
  containers, artifact count and size.

`clean` moves each artifact to `~/.Trash/<name>.<timestamp>` with `mv -n` and prints a restore
`mv` line per item. It skips anything inside a WhatsApp container. Nothing is ever `rm`'d.

## Presentation

1. **Artifacts table** (if any): `| Type | Path | Size |`
2. **Container table** (always): `| Container | Files | Size |`
3. **Totals line**: total files, total size, containers with files, empty containers.
4. For `full`, also show the per-file / grouped listings.
5. For `clean`, after the real run show the moved items and their restore lines.

## Rules

- Never run `audit-icloud clean --yes` without the user confirming the dry-run list in chat.
- WhatsApp backups are encrypted — the CLI never touches them; do not work around that.
- `*.tmp` can match real files; call out any `.tmp` entry in the list before asking.
- Moves inside an iCloud container sync to every device; say so if the list is large.

## Troubleshooting

- **Permission denied**: iCloud Drive may be syncing. Wait and retry.
- **Output too large**: use `summary`.
- **Missing containers**: some containers only appear after their app has been opened once.
- **Restoring something**: paste the `restore: mv -n …` line the CLI printed.

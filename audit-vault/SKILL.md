---
user-invocable: true
name: audit-vault
description: "Read-only audit of the Obsidian vault for broken wikilinks, invalid tags, frontmatter schema, orphan notes, file naming, and empty files. Use when user says 'audit vault', 'vault health', 'check my notes', or periodically for hygiene."
argument-hint: "[full|tags|frontmatter|links|orphans|relevance]"
---

# Audit Vault

**Read-only: never edit, rename, or delete vault files. Report only.** Fix issues only if the user asks afterwards.

## Modes

Parse the argument; no argument means `full`.

- **`full`**: every check below except `relevance`
- **`tags`**: frontmatter tags (valid = stems of `40_indexes/*.md`, plus `journal` and `index`) and inline `#tags` in note bodies
- **`frontmatter`**: schema of `30_knowledge/` notes and articles, and tags on `00_inbox/` notes
- **`links`**: broken wikilinks and duplicate basenames
- **`orphans`**: orphan notes (no inbound link and no topic-index tag), near-empty files, snake_case file names, loose notes at the top of `30_knowledge/`
- **`relevance`**: opt-in tag relevance review (see below)

## Execution

```bash
bash ~/.claude/skills/audit-vault/scripts/audit_all.sh <mode>
```

The wrapper runs `audit_vault.py`, which uses only the Python standard library. The vault path comes from `VAULT` (default `~/Documents/obsidian`). Run Python only as `python3 -B -I` so no `__pycache__` lands in the skills repo.

## Tag Relevance Review (opt-in)

The script validates tags structurally. It cannot judge whether a tag fits a note, so `full` and `tags` skip that. Run it only for `relevance`:

1. Run `audit_all.sh relevance`. It prints one line per `30_knowledge/` note: `path | tags | description | first H1` (about 40 KB in total).
2. Do not read the notes yourself. Pass the whole list to one subagent. Ask it to flag only clear mismatches (a robotics paper tagged `finance`) and clearly missing valid tags (an AI paper without `ai`), judging from the line alone. It should return `path | tag | reason`, and skip anything uncertain.
3. Add its findings to the table as **Warning**, category `RELEVANCE`.

## Presenting Results

Every finding line starts with its severity: `[CRITICAL]`, `[WARNING]`, or `[COSMETIC]`. Present them as a table grouped by severity:

| Severity | Category | Issue | File |
|----------|----------|-------|------|

- **Critical**: `BROKEN` wikilinks in note bodies, notes with no frontmatter, `INVALID` frontmatter tags
- **Warning**:
  - `MISSING` or empty required fields. Notes in `30_knowledge/` need `origin`, `tags`, `description`, `type`, `status`. Articles (have `source:`, are not `type: reference` or `origin: ai`) need `origin`, `title`, `source`, `author`, `published`, `created`, `description`, `tags`. Fields are required, not optional.
  - `INVALID` `origin`, `type`, or `status` values
  - `MALFORMED` tags (an unclosed `[` list, or items starting with `#`, which YAML reads as comments)
  - `BROKEN` links in frontmatter, such as an author link with no note
  - `BODYTAG` in notes that are not clipped articles
  - `ORPHAN`, `NAMING`, `TOPLEVEL`, `DUPLICATE` basenames, `MISSING-DIR`
- **Cosmetic**: `EMPTY` files, `QUOTED` tags, `BODYTAG` in clipped articles or `60_archive/`, invalid or malformed tags in `60_archive/`, a long human note without `summary`

For each finding, suggest a specific fix (for example "Fill `published:` from the source page", "Create the target note or remove the link", "Move the note into a topic folder"). If nothing is found, confirm the vault is healthy.

A line starting `[ERROR] <check>:` means that check crashed, and `[ERROR] load: <file>` means a file could not be read. The other checks still ran. Report either as a tooling failure, not a vault issue.

## Troubleshooting

- **"Vault not found" (exit 2)**: `~/Documents/obsidian` does not exist at that path. Set `VAULT=/actual/path` and rerun.
- **`MISSING-DIR` warning**: `40_indexes/`, `30_knowledge/`, or `00_inbox/` is missing, so that check was skipped. Confirm the vault path. Without `40_indexes/`, tag and orphan results are not meaningful.
- **A `BROKEN` link you believe is fine**: links are matched case-insensitively by name, and path links (`[[folder/note]]`) by path suffix. Dot-folders (`.obsidian`, `.trash`) are not indexed, and a note moved out of the linked path counts as broken. Open the link in Obsidian to confirm. Code spans and fenced blocks are ignored.
- **`[ERROR] load:` or `[ERROR] <check>:`**: one file is unreadable or one check failed. Rerun just that mode to isolate it. Do not "fix" the vault in response.

---
name: audit-vault
description: "Audit Obsidian vault for broken wikilinks, invalid tags, missing frontmatter, orphan notes, and empty files. Use when user says 'audit vault', 'vault health', 'check my notes', or periodically for hygiene."
argument-hint: "[full|tags|frontmatter|links|orphans]"
---

# Audit Vault

Parse the argument to determine which mode to run:

- **`full`** (or no argument) — run all checks
- **`tags`** — only check tag validity
- **`frontmatter`** — only check frontmatter compliance
- **`links`** — only check broken wikilinks
- **`orphans`** — only check orphan notes and empty files

## Execution

Based on the mode, run the appropriate script:

- `full` or no argument:
  ```bash
  bash ~/.claude/skills/audit-vault/scripts/audit_all.sh
  ```
- `tags`:
  ```bash
  bash ~/.claude/skills/audit-vault/scripts/check_tags.sh
  ```
- `frontmatter`:
  ```bash
  bash ~/.claude/skills/audit-vault/scripts/check_frontmatter.sh
  ```
- `links`:
  ```bash
  bash ~/.claude/skills/audit-vault/scripts/check_links.sh
  ```
- `orphans`:
  ```bash
  bash ~/.claude/skills/audit-vault/scripts/check_orphans.sh
  ```

## Presenting Results

After running the script(s), present results as a **table grouped by severity**:

| Severity | Category | Issue | File |
|----------|----------|-------|------|

**Severity levels:**
- **Critical** — Broken wikilinks, missing frontmatter entirely, invalid tags
- **Improvement** — Missing optional frontmatter fields (author, published, etc.), orphan notes
- **Cosmetic** — Near-empty files, minor metadata gaps

For each issue found, suggest a specific fix (e.g., "Add `source:` field to frontmatter", "Create target note or remove link").

If no issues are found, confirm the vault is healthy.

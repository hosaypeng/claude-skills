---
user-invocable: true
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

## Tag Relevance Review (Agent Step)

The bash script only checks structural validity — it cannot assess whether a tag actually matches a note's content. After running any check that includes tags (`full`, `tags`), perform this agent-level review:

1. **Scope**: All `.md` files in `30_knowledge/` (tags are required there per vault convention).
2. **For each file**: Read the frontmatter tags and enough body content to judge topic (first 80 lines is usually sufficient).
3. **Flag as irrelevant** if a tag would not make sense to a reader given the note's actual subject matter. Examples of mismatches:
   - An arXiv robotics paper tagged `finance`
   - A trading memo tagged `biotech`
   - A note about diet tagged `geopolitics`
4. **Flag as missing** if the note's content clearly belongs to a valid tag that isn't listed (e.g., an AI paper with no `ai` tag).
5. Add all findings to the results table under severity **Improvement**.

Do not flag tags that are broadly reasonable — only clear mismatches. When uncertain, skip.

## Presenting Results

After running the script(s), present results as a **table grouped by severity**:

| Severity | Category | Issue | File |
|----------|----------|-------|------|

**Severity levels:**
- **Critical** — Broken wikilinks, missing frontmatter entirely, invalid tags
- **Improvement** — Missing optional frontmatter fields (author, published, etc.), orphan notes, missing `description`, `type`, or `status` in 30_notes/ frontmatter
- **Cosmetic** — Near-empty files, minor metadata gaps, quoted tags, missing `summary` on long notes

For each issue found, suggest a specific fix (e.g., "Add `source:` field to frontmatter", "Create target note or remove link").

If no issues are found, confirm the vault is healthy.

## Troubleshooting

- **Script fails with "No such file or directory"**: The vault path in the script may not match the actual vault location. Verify the path.
- **False positives for broken wikilinks**: Links may point to aliases or notes with special characters. Cross-check flagged links in Obsidian.
- **Permission denied errors**: iCloud Drive may be syncing. Wait a moment and retry.

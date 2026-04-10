---
user-invocable: true
name: update-dependencies
description: "Sweep all dependency paths after vault structural changes (file moves, renames, deletions). Auto-fixes safe issues, reports risky ones. Use when user says 'update dependencies', 'check dependencies', 'sweep deps', or after bulk vault changes."
---

# Update Dependencies

Run all 6 checks in order. Auto-fix safe issues, report risky ones.

**Vault root:** `~/Library/Mobile Documents/iCloud~md~obsidian/Documents`

## 1. Vault-rag index (AUTO-FIX)

```python
import json, os
path = os.path.expanduser('~/Code/vault-rag/index_state.json')
vault = os.path.expanduser('~/Library/Mobile Documents/iCloud~md~obsidian/Documents')
with open(path) as f:
    data = json.load(f)
before = len(data)
stale = [p for p in data if not os.path.exists(os.path.join(vault, p))]
for s in stale:
    del data[s]
if stale:
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
```

Run this via `python3 -c "..."`. Report: `Removed N stale entries (M remaining)`.

## 2. Wikilinks (REPORT)

1. Build a set of all `.md` file stems (without extension) across the entire vault
2. Grep for `\[\[([^\]]+)\]\]` in `30_knowledge/`, `50_areas/`, `20_projects/`, `00_inbox/`
3. For each wikilink, extract the target (before `|` if aliased)
4. Check if target exists in the file stems set
5. **Skip** `books.md` and `papers.md` — these have intentional unresolved refs
6. Report broken links grouped by file, with count

## 3. Config file paths (REPORT)

Scan these files for dead paths:
- `~/.claude/CLAUDE.md`
- Vault `CLAUDE.md`
- `MEMORY.md` (in the project memory dir)
- All `.md` files in the project memory dir

For each file:
1. Extract paths — look for backtick-wrapped paths (`` `~/...` ``, `` `vault ...` ``), and bare paths starting with `~/`, `/Users/`, or vault-relative paths
2. Resolve `~` to home dir, vault-relative paths to vault root
3. Check each path exists on filesystem
4. **Skip lines that are clearly historical** — lines containing words like "Phase", "removed", "deleted", "renamed", "merged", "archived", "was", "were", "formerly", past-tense context
5. Report dead paths as `file:line → dead_path`

## 4. LaunchAgent plists (REPORT)

1. Read all `~/Library/LaunchAgents/*.plist` files
2. For each, extract the script path from `<key>ProgramArguments</key>` array
3. Check if the script file exists on disk
4. **Skip** paths that are system commands (`/bin/bash`, `/usr/bin/env`, etc.)
5. Report dead script paths as `plist_name → dead_path`

## 5. Dir tree Quick Lookup (REPORT)

1. Read `50_areas/personal/directory_tree.md`
2. Find the Quick Lookup table
3. For each row, extract the path from the Location column
4. Resolve vault-relative paths (e.g., `vault 30_knowledge/`) to full paths
5. Check if the referenced file/dir exists
6. Report any rows where the path doesn't resolve

## 6. Frontmatter compliance (REPORT)

1. In `30_knowledge/`: count files missing `origin`, `type`, or `status` (skip `_index.md`)
2. In `00_inbox/`: count files with no YAML frontmatter at all (skip `_index.md`)
3. Report counts only (not individual files — keep it concise)

## Output Format

Present results as:

```
## Dependency Sweep Results

### Auto-fixed
- Vault-rag: removed N stale entries (M remaining)

### Needs Attention
| Check             | Issues | Details                    |
|-------------------|--------|----------------------------|
| Broken wikilinks  | N      | file1.md (2), file2.md (1) |
| Dead paths        | N      | source:line details        |
| LaunchAgent       | N      | plist → dead_path          |
| Dir tree drift    | N      | row details                |
| Frontmatter gaps  | N      | 30_knowledge: X, inbox: Y  |

### Summary
N issues auto-fixed, M issues need attention.
```

If a check finds 0 issues, show "Clean" in the Details column. Do NOT omit clean rows — show all 5 checks for completeness.

## Rules

- NEVER edit LaunchAgent plists, CLAUDE.md, or MEMORY.md — only report
- NEVER delete vault files — only report
- Auto-fix is limited to: vault-rag `index_state.json` stale entry removal
- Do NOT flag `books.md` or `papers.md` wikilinks — those are intentionally unresolved
- Do NOT flag historical/past-tense references in MEMORY.md — those document what happened, not live paths

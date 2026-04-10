---
name: standardize-filenames
description: "Instantly standardize all filenames in a directory to lowercase snake_case with YYYY-MM-DD dates. Use when user says 'fix filenames', 'standardize filenames', 'rename files to snake_case', 'clean up file names', or after downloading files that need consistent naming."
allowed-tools: Bash, Glob, Grep, Read, Write, Edit
user-invocable: true
argument-hint: "[directory|all] [--recursive] [--dry-run|--execute]"
---

# Filename Standardization

See `~/.claude/skills/standardize-filenames/references/conventions.md` for naming rules and examples.

## Steps

### 1. Back up

If the target is a small directory (< a few hundred files), back up in place:
```bash
cp -r "<target_dir>" "<target_dir>_backup_$(date +%Y%m%d_%H%M%S)"
```
For large directories (entire vault, downloads folder), back up to `/tmp/` to avoid iCloud upload:
```bash
cp -r "<target_dir>" "/tmp/$(basename <target_dir>)_backup_$(date +%Y%m%d_%H%M%S)"
```

### 2. Dry-run scan

If no directory was specified or the argument is `all`, use the current working directory:
```bash
bash ~/.claude/skills/standardize-filenames/scripts/standardize.sh "." [--recursive] --dry-run
```
Otherwise use the provided path:
```bash
bash ~/.claude/skills/standardize-filenames/scripts/standardize.sh "<target_dir>" [--recursive] --dry-run
```

### 3. Analyze directory context
The script handles mechanical transforms. The agent must also handle:
- **Detect dominant pattern**: if >50% of files share a structure (e.g., `YYYY-MM-DD_trust_statement.pdf`), that's the directory convention. Outliers that don't match should be read to extract correct metadata and renamed to match.
- **Complex dates**: month names, content-based dates from PDFs.
- **Noise removal**: watermarks, website tags, redundant publisher names.
- **Semantic structuring**: periodical vs book vs article conventions (see conventions.md).

Add any agent-identified renames to the plan manually.

### 4. Execute
```bash
bash ~/.claude/skills/standardize-filenames/scripts/standardize.sh "<target_dir>" [--recursive] --execute
```
For manual renames beyond the script, use `mv -n`. All safety rules from global CLAUDE.md apply (two-pass for overlaps, stop on failure). Note: `mv -n` on macOS fails silently — verify source no longer exists after move.

### 5. Verify and report
Verify per global CLAUDE.md rules. Content-based renames: read every file and confirm content matches new name. Mismatch → restore from backup. Then print a concise summary of what was renamed.

### 6. Update wikilinks (Markdown vaults only)
If any renamed files are `.md` files inside an Obsidian vault, their old filenames may appear as `[[wikilinks]]` in other notes. After renaming, search for stale references:
```bash
grep -rF "[[OldFilename]]" <vault_dir> --include="*.md"
```
Update each occurrence, or run `/update-dependencies` to sweep the vault automatically.

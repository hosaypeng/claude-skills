---
name: standardize-filenames
description: "Instantly standardize all filenames in a directory to lowercase snake_case with YYYY-MM-DD dates. Use when user says 'fix filenames', 'standardize filenames', 'rename files to snake_case', 'clean up file names', or after downloading files that need consistent naming."
allowed-tools: Bash, Glob, Read
user-invocable: true
argument-hint: "[directory] [--recursive] [--dry-run]"
---

# Filename Standardization for AI Agentic Workflows

Automatically and immediately standardize all filenames in the current directory to maximize AI agent efficiency, parseability, and workflow automation.

## Core Principle

**Optimize filenames for machine readability and AI agent processing** - prioritize consistency, predictability, and programmatic access over human aesthetics.

## Naming Conventions

See `~/.claude/skills/standardize-filenames/references/conventions.md` for naming rules, date formats, transformation examples, and directory context analysis.

## Instructions

When invoked with `/standardize-filenames`, **execute immediately** without confirmation:

### 1. Scan Directory
```bash
# Get all files in target directory (non-recursive by default, pass --recursive for subdirs)
bash ~/.claude/skills/standardize-filenames/scripts/standardize.sh [directory] [--recursive]
```

### 2. Analyze Directory Context (CRITICAL)

**Before applying any transformations, analyze the existing filenames to detect patterns.** See directory context analysis in `~/.claude/skills/standardize-filenames/references/conventions.md`.

### 3. Transform Each Filename

Apply transformations in this order:

Apply noise removal, date standardization, cleaning, and semantic structuring per `~/.claude/skills/standardize-filenames/references/conventions.md`.

### 4. Conflict Resolution

If target filename exists:
- Append `_2`, `_3`, etc.
- Do NOT overwrite existing files

### 5. Execute Renames

Execute all renames immediately using `mv` commands. For each file that needs renaming, run:
```bash
mv "original_name.ext" "new_name.ext"
```
Renames are atomic per-file operations and safe to execute individually.

### 6. Report Results

After execution, provide concise summary:
```
✓ Renamed X files
✗ Skipped Y files (already standardized)
⚠ Z conflicts (appended _2, _3, etc.)

Sample changes:
- old_name.pdf → new_name.pdf
- another_file.pdf → 2024-01-15_another_file.pdf
[show up to 10 examples]
```

## Transformation Examples

See `~/.claude/skills/standardize-filenames/references/conventions.md` for full examples (magazines, books, articles, newspapers).

## Execution Mode

**Default: Execute immediately** - no confirmation required.

The skill trusts that you've invoked it intentionally and acts autonomously.

## Safety Boundaries

1. **Non-destructive**: Only renames, never deletes
2. **Conflict-aware**: Never overwrites existing files
3. **Extension-preserving**: Always maintains file type
4. **Non-recursive**: Only current directory (unless `--recursive` flag)
5. **Atomic operations**: Each rename is independent

## Advanced Usage

Optional flags (parse from user message):
- `--recursive` or `-r`: Include subdirectories
- `--dry-run`: Preview only, don't execute (if user explicitly requests)

Default behavior: current directory, execute immediately.

## Troubleshooting

- **mv fails with "No such file or directory"**: The file may have been renamed by a prior step. Re-scan the directory and retry.
- **Filename contains characters that break shell quoting**: Always wrap both source and target paths in double quotes.
- **Date format ambiguity (DD-MM vs MM-DD)**: Inspect sibling files for a consistent convention. Default to the directory's dominant pattern.

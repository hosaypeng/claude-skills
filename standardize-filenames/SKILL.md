---
name: standardize-filenames
description: "Instantly standardize all filenames in a directory to lowercase snake_case with YYYY-MM-DD dates. Use when user says 'fix filenames', 'standardize filenames', 'rename files to snake_case', 'clean up file names', or after downloading files that need consistent naming."
allowed-tools: Bash, Glob, Read, Write
user-invocable: true
argument-hint: "[directory] [--recursive] [--dry-run]"
---

# Filename Standardization for AI Agentic Workflows

Automatically and immediately standardize all filenames in the current directory to maximize AI agent efficiency, parseability, and workflow automation.

## Core Principle

**Optimize filenames for machine readability and AI agent processing** - prioritize consistency, predictability, and programmatic access over human aesthetics.

**Safety is non-negotiable.** Every rename operation uses `mv -n` (no-clobber). No file is ever silently overwritten. Backups are created before any batch operation.

## Naming Conventions

See `~/.claude/skills/standardize-filenames/references/conventions.md` for naming rules, date formats, transformation examples, and directory context analysis.

## Instructions

When invoked with `/standardize-filenames`, follow these steps in order:

### 1. Back Up the Directory

**Before any renames, back up the target directory.** This is mandatory and must not be skipped.

```bash
cp -r "<target_dir>" "<target_dir>_backup_$(date +%Y%m%d_%H%M%S)"
```

Write a backup manifest listing the backup path and timestamp using the Write tool so there is a record.

### 2. Scan and Generate Rename Plan

Run the standardization script in dry-run mode to generate the rename plan:

```bash
bash ~/.claude/skills/standardize-filenames/scripts/standardize.sh "<target_dir>" [--recursive] --dry-run
```

The script will:
- Scan all files (excluding hidden files)
- Apply mechanical normalization (lowercase, snake_case, date format, special character removal)
- Detect collisions (target names that match existing source names)
- Print the full old-to-new mapping for review

### 3. Analyze Directory Context (CRITICAL)

**Before executing, analyze the existing filenames to detect patterns.** See directory context analysis in `~/.claude/skills/standardize-filenames/references/conventions.md`.

The script handles mechanical transformations. The agent must handle:
- Complex date extraction (month names, content-based dates from PDFs)
- Semantic structuring (periodical vs. book vs. article conventions)
- Noise pattern removal (watermarks, website tags)
- Outlier inspection (reading file contents to determine correct metadata)

If the agent identifies renames beyond what the script generates, add them to the plan manually and apply the same safety rules below.

### 4. Collision Check and Two-Pass Rename Strategy

**MANDATORY: If ANY target name matches ANY existing source name, rename to temporary names first (`.tmp` suffix), then rename to final names.** The script handles this automatically when run with `--execute`. For manual renames, always follow this pattern:

```bash
# Pass 1: rename to temporary names
mv -n "source_a.pdf" "target_b.pdf.tmp"
mv -n "source_b.pdf" "target_a.pdf.tmp"

# Pass 2: rename to final names
mv -n "target_b.pdf.tmp" "target_b.pdf"
mv -n "target_a.pdf.tmp" "target_a.pdf"
```

**Why this matters:** Without two-pass rename, if `a.pdf` must become `b.pdf` and `b.pdf` must become `a.pdf`, a single-pass rename will overwrite one file with the other. Reverse-order renaming does NOT prevent this — it causes cascading overwrites.

### 5. Execute Renames

**All renames MUST use `mv -n` (no-clobber).** Never use bare `mv`. If `mv -n` fails (destination exists), that signals a logic error in the plan — stop and re-plan.

Option A — Use the script:
```bash
bash ~/.claude/skills/standardize-filenames/scripts/standardize.sh "<target_dir>" [--recursive] --execute
```

Option B — Manual renames (for agent-identified changes beyond the script):
```bash
mv -n "original_name.ext" "new_name.ext"
```

**If any `mv -n` fails, STOP.** Do not continue with remaining renames. Diagnose the collision first.

### 6. Verify Content After Rename

**CRITICAL — This step is mandatory, not optional.**

After all renames complete, verify that the right data is in the right files:

- For content-based renames (where the filename was derived from file content, e.g., reading a PDF to determine its date): **Read every renamed file and confirm the content matches the new filename.** A mislabeled financial document can have severe real-world consequences. This is non-negotiable.
- For mechanical renames (simple case/format changes): spot-check at least 3 files to confirm content is intact.
- If any file's content does not match its new name, restore from backup immediately.

### 7. Report Results

After execution and verification, provide concise summary:
```
Backup: <backup_path>
Renamed: X files
Skipped: Y files (already standardized)
Conflicts resolved: Z (appended _2, _3, etc.)
Two-pass rename used: yes/no

Sample changes:
- old_name.pdf -> new_name.pdf
- another_file.pdf -> 2024-01-15_another_file.pdf
[show up to 10 examples]
```

## Safety Boundaries

1. **Non-destructive**: Only renames, never deletes
2. **Backup first**: `cp -r dir dir_backup` before any batch operation
3. **No-clobber always**: Every `mv` command uses `-n` flag — never bare `mv`
4. **Two-pass for overlaps**: If any target name matches any source name, rename via `.tmp` intermediary
5. **Verify after rename**: Read file contents after renames to confirm correctness
6. **Conflict-aware**: Duplicate targets get `_2`, `_3` suffixes — never overwrites
7. **Extension-preserving**: Always maintains file type
8. **Non-recursive by default**: Only current directory (unless `--recursive` flag)
9. **Atomic operations**: Each rename is independent
10. **Stop on failure**: If `mv -n` fails, halt and diagnose before continuing

## Advanced Usage

Optional flags (parse from user message):
- `--recursive` or `-r`: Include subdirectories
- `--dry-run`: Preview only, don't execute (if user explicitly requests)

Default behavior: current directory, execute immediately (but always with backup, plan review, and `mv -n`).

## Troubleshooting

- **mv -n fails silently**: `mv -n` on macOS does not print an error when it refuses to overwrite — it just does nothing. After execution, verify the source file no longer exists AND the destination file exists. If the source still exists, the move was blocked by a collision.
- **mv fails with "No such file or directory"**: The file may have been renamed by a prior step. Re-scan the directory and retry.
- **Filename contains characters that break shell quoting**: Always wrap both source and target paths in double quotes.
- **Date format ambiguity (DD-MM vs MM-DD)**: Inspect sibling files for a consistent convention. Default to the directory's dominant pattern.

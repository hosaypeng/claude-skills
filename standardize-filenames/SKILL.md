---
name: standardize-filenames
description: "Instantly standardize all filenames in a directory to lowercase snake_case with YYYY-MM-DD dates. Use when user says 'fix filenames', 'standardize filenames', 'rename files to snake_case', 'clean up file names', or after downloading files that need consistent naming."
allowed-tools: Bash, Glob, Read
---

# Filename Standardization for AI Agentic Workflows

Automatically and immediately standardize all filenames in the current directory to maximize AI agent efficiency, parseability, and workflow automation.

## Core Principle

**Optimize filenames for machine readability and AI agent processing** - prioritize consistency, predictability, and programmatic access over human aesthetics.

## Naming Conventions

1. **Lowercase only**: `FileNAME.pdf` → `filename.pdf`
2. **Snake_case for text**: `File Name.pdf` → `file_name.pdf`
3. **Kebab-case for dates**: `2024-01-15` (ISO 8601 standard, chronologically sortable)
4. **Date prefix when present**: `YYYY-MM-DD_description.ext`
5. **No special characters**: Only `a-z`, `0-9`, `_`, `-`, `.`
6. **Single separators**: `file__name` → `file_name`
7. **No trailing separators**: `file_.pdf` → `file.pdf`
8. **Descriptive and concise**: Remove redundant publisher tags, preserve meaningful metadata

## AI Workflow Optimization

### Why These Conventions?

**For AI Agents:**
- **Predictable patterns**: Regex and parsing rules work consistently
- **No escaping needed**: Shell, Python, JS can reference directly without quotes
- **Semantic structure**: `YYYY-MM-DD_source_topic_version.ext` is machine-parseable
- **Sortable by default**: Dates sort chronologically, names alphabetically
- **Token-efficient**: Shorter, cleaner names = fewer LLM tokens

**For Automation:**
- **Glob-friendly**: `*_2024-*.pdf` reliably matches date patterns
- **Version control safe**: Git handles these filenames without issues
- **Cross-platform**: Works identically on Windows, Mac, Linux
- **Script-friendly**: Can be used in bash/python variables without escaping

**For Search & Retrieval:**
- **grep/ripgrep optimized**: Consistent patterns make searching faster
- **Fuzzy find compatible**: Tab completion works smoothly
- **Semantic chunking**: `source_date_topic` structure aids RAG systems

## Date Format: YYYY-MM-DD (Kebab-Case)

Dates ALWAYS use kebab-case (hyphens) following ISO 8601:
- `2024-01-15` ✓ (ISO standard, chronologically sortable)
- `2024_01_15` ✗ (not standard)
- `01-15-2024` ✗ (ambiguous, sorts incorrectly)

## Instructions

When invoked with `/standardize-filenames`, **execute immediately** without confirmation:

### 1. Scan Directory
```bash
# Get all files in current directory (non-recursive by default)
find . -maxdepth 1 -type f -not -name ".*"
```

### 2. Analyze Directory Context (CRITICAL)

**Before applying any transformations, analyze the existing filenames to detect patterns.**

This step prevents blind formatting that ignores semantic meaning. A file named `PDF document.pdf` in a folder of `YYYY-MM-DD_trust_statement.pdf` files is not just poorly formatted—it's a mislabeled trust statement.

#### A. Detect Dominant Naming Pattern
- Count files that share a common structure (e.g., `YYYY-MM-DD_description.pdf`)
- If >50% of files follow a specific semantic pattern, that's the **directory convention**
- Examples of directory conventions:
  - `YYYY-MM-DD_trust_statement.pdf` (bank statements)
  - `YYYY-MM_publication_name.pdf` (magazines)
  - `author_title.pdf` (books)

#### B. Identify Outliers
- Files that don't match the dominant pattern are **outliers**
- Generic names like `PDF document.pdf`, `untitled.pdf`, `download.pdf` are always outliers
- Outliers likely contain the same type of content but are mislabeled

#### C. Inspect Outlier Contents
- **Read the file** (especially PDFs) to extract correct metadata:
  - Statement dates, issue dates, publication dates
  - Document titles, authors, sources
- Use this metadata to construct the correct filename matching the directory convention

#### D. Pattern Matching Examples
```
Directory contains:
  2025-02-15_trust_statement.pdf
  2025-03-18_trust_statement.pdf
  2025-04-17_trust_statement.pdf
  PDF document.pdf  ← OUTLIER

Action: Read PDF document.pdf, find statement date (e.g., Jan 18, 2026)
Result: Rename to 2026-01-18_trust_statement.pdf
```

```
Directory contains:
  2024-01_american_cinematographer.pdf
  2024-02_american_cinematographer.pdf
  magazine_scan.pdf  ← OUTLIER

Action: Read magazine_scan.pdf, find issue date (e.g., March 2024)
Result: Rename to 2024-03_american_cinematographer.pdf
```

### 3. Transform Each Filename

Apply transformations in this order:

#### A. Remove Common Noise Patterns
- `_OceanofPDF.com_` → remove
- `[website]_`, `(website)_` → remove
- Website watermarks at start/end → remove

#### B. Detect and Standardize Dates
Recognize these patterns and convert to `YYYY-MM-DD`:
- `MM-DD-YYYY`, `MM/DD/YYYY`, `MM.DD.YYYY`
- `DD-MM-YYYY`, `DD/MM/YYYY`, `DD.MM.YYYY` (context-dependent)
- `YYYYMMDD` → `YYYY-MM-DD`
- `YYYY_MM_DD` → `YYYY-MM-DD`
- Month names: `January_15_2024`, `Jan_15_2024` → `2024-01-15`
- `Month_YYYY` → `YYYY-MM` (when day unknown)

Position date at the start if it represents publication/issue date.

#### C. Clean and Normalize
1. Convert to lowercase
2. Replace spaces with underscores: `File Name` → `file_name`
3. Replace hyphens with underscores EXCEPT in dates: `file-name` → `file_name`, but keep `2024-01-15`
4. Remove special characters: `()[]{}!@#$%^&*+=;:'",<>?/\|` → remove or replace with `_`
5. Collapse multiple underscores: `file___name` → `file_name`
6. Remove leading/trailing underscores: `_file_` → `file`
7. Remove redundant words: `american_cinematographer_january_2024_american_cinematographer` → `2024-01_american_cinematographer`

#### D. Semantic Structuring

For periodicals/magazines/newspapers:
```
YYYY-MM-DD_publication_name.ext
or
YYYY-MM_publication_name.ext  (if day unknown)
```

For books:
```
title_author.ext
or
title_volume_author.ext
```

For articles:
```
YYYY-MM-DD_title_source.ext
or
title_topic.ext  (if no date)
```

### 3. Conflict Resolution

If target filename exists:
- Append `_2`, `_3`, etc.
- Do NOT overwrite existing files

### 4. Execute Renames

Execute all renames immediately:
```bash
mv "original_name.ext" "new_name.ext"
```

### 5. Report Results

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

### Magazines/Periodicals
```
Before: _OceanofPDF.com_American_Cinematographer_-_January_2024_-_American_Cinematographer.pdf
After:  2024-01_american_cinematographer.pdf

Before: 2026-01-03 Financial Times Weekend USA.pdf
After:  2026-01-03_financial_times_weekend_usa.pdf

Before: The Wall Street Journal - December 15, 2025.pdf
After:  2025-12-15_wall_street_journal.pdf

Before: Bloomberg Businessweek 2025-12-01.pdf
After:  2025-12-01_bloomberg_businessweek.pdf
```

### Books
```
Before: Vagabond Vol. 2 (2nd Edition) - Takehiko Inoue.pdf
After:  vagabond_vol_2_2nd_edition_takehiko_inoue.pdf

Before: The Hard Thing About Hard Things.pdf
After:  the_hard_thing_about_hard_things.pdf

Before: Abundance- The Future Is Better Than You Think - Peter H Diamandis.epub
After:  abundance_the_future_is_better_than_you_think_peter_h_diamandis.epub
```

### Articles
```
Before: Peter Thiel - Allergic to AI (The Spectator).pdf
After:  peter_thiel_allergic_to_ai_the_spectator.pdf

Before: Justin McDaniel - Students Read Again.pdf
After:  justin_mcdaniel_students_read_again.pdf
```

### Newspapers
```
Before: 2025-11-06 Financial Times UK.pdf
After:  2025-11-06_financial_times_uk.pdf

Before: ft_uk.pdf
After:  ft_uk.pdf  (already optimal)

Before: FT Weekend Magazine.pdf
After:  ft_weekend_magazine.pdf
```

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

## AI Agent Benefits

This standardization enables:
- **Automated batch processing**: Scripts can reliably find and process files
- **Semantic file discovery**: Date and topic extraction from filename alone
- **Efficient RAG indexing**: Consistent naming improves vector search
- **Reliable cross-references**: AI can reference files without ambiguity
- **Reduced token usage**: Shorter, cleaner paths in prompts
- **Better context windows**: More files can be referenced in limited context
- **Programmatic filtering**: Easy to select files by date, source, type
- **Workflow chaining**: Output from one agent becomes predictable input for next

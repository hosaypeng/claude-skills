# Filename Conventions

## Rules
1. **Lowercase only**: `FileNAME.pdf` → `filename.pdf`
2. **Snake_case**: spaces/hyphens → underscores (except in dates)
3. **Dates as YYYY-MM-DD prefix**: ISO 8601, kebab-case, chronologically sortable
4. **Allowed chars**: `a-z`, `0-9`, `_`, `-`, `.` only
5. **Single separators**: collapse `__` → `_`, strip leading/trailing `_`
6. **`&` → `and`**: preserves meaning (`Testing & Scaling` → `testing_and_scaling`)
7. **Dots in stems → underscores**: `1.0.95` → `1_0_95` (extension preserved separately)
8. **Strip timestamps**: WhatsApp-style `at HH.MM.SS` → remove
9. **Strip noise**: `_OceanofPDF.com_`, `z-lib.org`, `libgen`, website watermarks → remove
10. **Strip redundant words**: repeated publisher/title names → deduplicate
11. **Strip meaningless numeric IDs**: `638199_a_users_guide.pdf` → `a_users_guide.pdf`

## Date Detection
Convert all date patterns to `YYYY-MM-DD`:
- `MM-DD-YYYY`, `MM/DD/YYYY`, `DD-MM-YYYY`, `YYYYMMDD`, `YYYY_MM_DD`
- Month names: `January_15_2024` → `2024-01-15`
- `Month_YYYY` → `YYYY-MM` (day unknown)
- Date ambiguity (DD-MM vs MM-DD): use the directory's dominant pattern

Position date at start if it represents publication/issue date.

## Examples
```
_OceanofPDF.com_American_Cinematographer_-_January_2024.pdf → 2024-01_american_cinematographer.pdf
The Wall Street Journal - December 15, 2025.pdf             → 2025-12-15_wall_street_journal.pdf
Vagabond Vol. 2 (2nd Edition) - Takehiko Inoue.pdf          → vagabond_vol_2_2nd_edition_takehiko_inoue.pdf
WhatsApp Image 2026-03-06 at 14.24.27.jpeg                  → 2026-03-06_whatsapp_image.jpeg
Peter Thiel - Allergic to AI (The Spectator).pdf             → peter_thiel_allergic_to_ai_the_spectator.pdf
2026-01-03 Financial Times Weekend USA.pdf                   → 2026-01-03_financial_times_weekend_usa.pdf
```

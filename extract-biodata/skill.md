---
name: extract-biodata
description: "Extract applicant biodata from PDF files and auto-populate biodata_summary.md tables. Use when user says 'extract biodata', 'process biodata PDFs', 'update biodata table', or 'scan applicant PDFs'."
user-invocable: true
---

# Instructions

## 1. OCR First
Run `~/.venvs/pdf-tools/bin/python3 ~/Code/personal-finance-pipeline/extract_biodata.py . --dry-run`. Only use Claude's visual PDF reading for PDFs flagged as failed or low-confidence (especially box-style DOB, height, weight fields).

## 2. Extract from each PDF
- **Applicant Code** (top right: AS####, KT####, BMI###, JJ####, DW####, TMV######, EP###)
- **Name**, **DOB** (DD-MM-YYYY), **Age** (calculate from DOB or use stated)
- **Height** (cm), **Weight** (kg)
- **Children** (count and ages if available)
- **Religion**, **Education**, **Marital Status**
- **Work Experience** (none / local only / overseas), **Experience Countries**
- **Place of Birth**, **Nationality**

Flag missing critical fields (Code, Name, Age, Height, Weight). Cross-check code format against filename. Verify DOB/Age consistency if both present.

## 3. Update biodata_summary.md
- If file doesn't exist, ask user whether to create one or specify path.
- Match by Code or Name. **Only fill empty cells — NEVER overwrite existing data.**
- Conflicts with existing data: flag, don't change.
- Backup to `biodata_summary.md.backup-{timestamp}` before writing.
- Show proposed changes, confirm with user before applying.

## 4. Report
Summarize: processed/success/failed counts, per-candidate status, missing data by field, field completeness percentages.

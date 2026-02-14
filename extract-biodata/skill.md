---
name: extract-biodata
description: "Extract applicant biodata fields (name, age, height, weight, experience, etc.) from PDF files and auto-populate biodata_summary.md tables. Use when user says 'extract biodata', 'process biodata PDFs', 'update biodata table', or 'scan applicant PDFs'."
---

# Instructions

When I run /extract-biodata:

## Phase 1: Scan & Extract
1. Find all PDF files in the current directory
2. For each PDF, extract these fields:
   - **Applicant Code** (from top right: AS####, KT####, BMI###, JJ####, DW####, TMV######, EP###)
   - **Name** (full name as shown)
   - **Date of Birth** (format: DD-MM-YYYY)
   - **Age** (calculate from DOB if shown, or use stated age)
   - **Height** (in cm)
   - **Weight** (in kg)
   - **Number of Children** (and ages if available)
   - **Religion**
   - **Education Level**
   - **Marital Status**
   - **Work Experience** (categorize as: none, local only, overseas)
   - **Experience Countries** (if overseas: Singapore, Malaysia, Hong Kong, China, etc.)
   - **Place of Birth**
   - **Nationality**

## Phase 2: Validate
3. Check if extracted data is complete
4. Flag any missing critical fields (Code, Name, Age, Height, Weight)
5. Verify applicant code format matches expected patterns
6. Cross-check filename matches applicant code
7. Calculate age from DOB if both DOB and Age are present (verify they match)

## Phase 3: Update Table
8. Find biodata_summary.md in current directory
9. For each candidate:
   - If row exists (match by Code or Name): update ONLY empty fields with extracted data
   - If row missing: add new row with all extracted data
   - NEVER overwrite existing data in the table
10. Preserve existing manually-entered data
11. Maintain table formatting exactly (alignment, spacing, etc.)

## Phase 4: Report
12. Generate detailed completion report:
```
EXTRACTION REPORT
=================
Folder: indo_no_exp/
Date: 2026-01-31 02:30 AM

Total PDFs processed: 13
Successfully extracted: 11 (85%)
Partially extracted: 2 (15%)
Failed: 0 (0%)

EXTRACTION DETAILS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ AS1397 - Anita Devi: Extracted 12/12 fields
✓ AS1400 - Imas: Extracted 12/12 fields
⚠ AS1476 - Sumiati: Extracted 9/12 fields (missing children, height, weight)
✓ AS1514 - Indri Astuti: Extracted 12/12 fields
[... continue for all candidates]

MISSING DATA SUMMARY:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Children field not clear: AS1397, TMV260111 (2 candidates)
- Height not visible: TMV260119 (1 candidate)
- Weight not visible: TMV260119 (1 candidate)

FIELD COMPLETENESS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Code:      13/13 (100%) ████████████████████
Name:      13/13 (100%) ████████████████████
Age:       11/13 (85%)  █████████████████░░░
Height:    10/13 (77%)  ███████████████░░░░░
Weight:    10/13 (77%)  ███████████████░░░░░
Children:   9/13 (69%)  █████████████░░░░░░░
Religion:  13/13 (100%) ████████████████████
Education: 13/13 (100%) ████████████████████
```

13. Show a preview of what will be updated in the table:
```
PROPOSED UPDATES TO biodata_summary.md:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Row 1 (AS1397 - Anita Devi):
  Age: [empty] → 27
  Height: [empty] → 150
  Weight: [empty] → 65
  Children: [empty] → 2

Row 2 (AS1400 - Imas):
  Age: [empty] → 29
  Height: [empty] → 155
  Weight: [empty] → 58
  Children: [empty] → 1

[... continue for all rows with updates]
```

14. Ask: "Should I update the biodata_summary.md table with this data? (yes/no)"
15. If confirmed:
    - Make the updates
    - Show the updated table
    - Save a backup of the original table to `biodata_summary.md.backup-{timestamp}`
    - Confirm: "✓ Table updated successfully. Backup saved."

## Important Notes:
- NEVER overwrite existing data in the table (only fill empty cells)
- If extracted data conflicts with existing table data, flag it but don't change it
- Preserve table formatting exactly (markdown table structure)
- Always create a backup before making changes
- If confidence in extracted data is low (<80%), flag for manual review

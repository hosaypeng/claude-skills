---
name: extract-bank-statement
description: "Extract transactions from bank account PDF statements and output pipeline-compatible CSVs. Use when user says 'extract transactions from PDF', 'convert bank statement to CSV', or 'parse this bank statement'."
user-invocable: true
---

# Extract Bank Statement

Extract transactions from bank account PDF statements and output pipeline-compatible CSVs.

## Trigger

Use when the user says:
- "extract transactions from [PDF]"
- "convert bank statement PDF to CSV"
- "parse this bank statement"
- "extract data from bank statement"

## Supported Banks

| Bank | Statement type | Script |
|------|---------------|--------|
| Trust Bank | Savings account (monthly) | `extract_trust_bank_savings.py` |
| Trust Bank | Credit card (monthly) | `extract_trust_bank_cc.py` |

## Usage

### Savings account — single file
```bash
python3 ~/.claude/skills/extract-bank-statement/scripts/extract_trust_bank_savings.py \
  /path/to/statement.pdf \
  /path/to/output.csv
```

### Credit card — single file
```bash
python3 ~/.claude/skills/extract-bank-statement/scripts/extract_trust_bank_cc.py \
  /path/to/statement.pdf \
  /path/to/output.csv
```

Omit the output path on either script to print to stdout (useful for preview).

### Batch: all PDFs in a directory
```bash
SCRIPT=~/.claude/skills/extract-bank-statement/scripts/extract_trust_bank_cc.py
for f in /path/to/statements/pdf/*.pdf; do
  name=$(basename "$f" .pdf)
  python3 "$SCRIPT" "$f" "/path/to/output/${name}.csv"
done
```

## Output Schema

Matches the finance pipeline schema (`date, account, description, amount, type, category, balance`):

| Column | Format | Example |
|--------|--------|---------|
| date | YYYY-MM-DD | 2025-07-21 |
| account | "Trust Bank" | Trust Bank |
| description | as-is from statement | DE LUNA HOTEL KUALA LUMPUR MY |
| amount | positive float | 39.54 |
| type | "credit" or "debit" | debit |
| category | empty (pipeline categorizes) | |
| balance | empty (not in statement) | |

## Savings Account Rules

- Credits: SGD amount prefixed with `+` in the source PDF
- Debits: SGD amount with no prefix
- Skipped rows: "Previous balance", "Closing balance"
- Empty statements (all zeros): script prints a warning, no CSV rows emitted
- Year is derived from the "Statement period" header on page 1

## Credit Card Rules

- Credits: SGD amount prefixed with `+` (cashback, repayments)
- Debits: SGD amount with no prefix
- FCY transactions: exchange-rate and FCY-amount lines are skipped; only SGD amount is captured
- Skipped rows: "Previous balance", "Total outstanding balance"
- Section headers skipped: "Cashback credit card", "Link credit card", "Loans, Fees, Charges and Repayments"
- Year is derived from the "Statement cycle" header on page 1; cross-year cycles (e.g. Dec–Jan) are handled correctly
- Two PDF layouts supported automatically:
  - V1 (Feb–Jul 2025): single "Posting date" column
  - V2 (Aug 2025+): "Transaction date" + "Posting date" columns; posting date is used

## Dependency

Requires `pymupdf`:
```bash
pip install pymupdf
```

## Workflow Integration

After extracting CSVs, place them in the appropriate source directory
(e.g., `trust_bank_account_statements/`) and run the finance pipeline using the
`pipeline_script` path from `~/.claude/skills/extract-bank-statement/config.json`.
The pipeline will merge, categorize, and validate them into the master CSVs.

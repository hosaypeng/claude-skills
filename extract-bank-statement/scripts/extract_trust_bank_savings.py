#!/usr/bin/env python3
"""
Extract transactions from Trust Bank savings account PDF statements.
Outputs CSV matching the finance pipeline schema:
  date, account, description, amount, type, category, balance

Usage:
  python3 extract_trust_bank_savings.py statement.pdf [output.csv]
  python3 extract_trust_bank_savings.py statement.pdf  # prints to stdout
"""

import csv
import re
import sys
from datetime import datetime
from pathlib import Path

try:
    import fitz  # pymupdf
except ImportError:
    sys.exit("Error: pymupdf not installed. Run: pip install pymupdf")

MONTH_MAP = {
    "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
    "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12,
}

SKIP_DESCRIPTIONS = {"Previous balance", "Closing balance"}


def extract_year(page1_text: str) -> int:
    """Extract year from 'Statement period D Mon YYYY - D Mon YYYY' on page 1."""
    m = re.search(r"Statement period\s+\d+\s+\w+\s+(\d{4})", page1_text)
    if not m:
        raise ValueError("Could not find statement period on page 1")
    return int(m.group(1))


def parse_date(date_str: str, year: int) -> str:
    """Convert 'DD Mon' to 'YYYY-MM-DD'."""
    parts = date_str.strip().split()
    if len(parts) != 2:
        raise ValueError(f"Unexpected date format: {date_str!r}")
    day, mon = parts
    month_num = MONTH_MAP.get(mon)
    if not month_num:
        raise ValueError(f"Unknown month: {mon!r}")
    return f"{year}-{month_num:02d}-{int(day):02d}"


def clean_lines(raw_text: str) -> list[str]:
    """Strip, remove non-breaking spaces, drop empty lines."""
    lines = []
    for line in raw_text.split("\n"):
        line = line.replace("\xa0", "").strip()
        if line:
            lines.append(line)
    return lines


def extract_transactions(pdf_path: str) -> list[dict]:
    doc = fitz.open(pdf_path)

    page1_text = doc[0].get_text()
    year = extract_year(page1_text)

    transactions = []
    date_pattern = re.compile(r"^\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)$")
    amount_pattern = re.compile(r"^[+-]?[\d,]+\.\d{2}$")

    for page_num in range(1, len(doc)):
        page_text = doc[page_num].get_text()
        lines = clean_lines(page_text)

        # Find start of transaction data (after "Amount in SGD" header)
        try:
            start = lines.index("Amount in SGD") + 1
        except ValueError:
            continue

        lines = lines[start:]

        # Parse groups: date, description, amount
        i = 0
        while i < len(lines):
            line = lines[i]

            if not date_pattern.match(line):
                i += 1
                continue

            date_str = line
            desc = lines[i + 1] if i + 1 < len(lines) else ""
            amount_str = lines[i + 2] if i + 2 < len(lines) else ""

            # Skip balance marker rows
            if desc in SKIP_DESCRIPTIONS:
                i += 3
                continue

            # Validate amount
            if not amount_pattern.match(amount_str):
                i += 1
                continue

            is_credit = amount_str.startswith("+")
            amount = float(amount_str.lstrip("+").replace(",", ""))
            date = parse_date(date_str, year)

            transactions.append({
                "date": date,
                "account": "Trust Bank",
                "description": desc,
                "amount": amount,
                "type": "credit" if is_credit else "debit",
                "category": "",
                "balance": "",
            })

            i += 3

    return transactions


def write_csv(transactions: list[dict], output_path: str | None = None) -> None:
    fieldnames = ["date", "account", "description", "amount", "type", "category", "balance"]
    if output_path:
        with open(output_path, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(transactions)
        print(f"Wrote {len(transactions)} transactions to {output_path}")
    else:
        writer = csv.DictWriter(sys.stdout, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(transactions)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(f"Usage: {sys.argv[0]} statement.pdf [output.csv]")

    pdf_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None

    if not Path(pdf_path).exists():
        sys.exit(f"Error: file not found: {pdf_path}")

    transactions = extract_transactions(pdf_path)

    if not transactions:
        print(f"No transactions found in {pdf_path} (statement may be empty)")
        if output_path:
            # Write empty CSV with headers
            write_csv([], output_path)
    else:
        write_csv(transactions, output_path)

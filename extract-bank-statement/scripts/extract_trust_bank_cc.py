#!/usr/bin/env python3
"""
Extract transactions from Trust Bank credit card PDF statements.

Output schema:
  date, account, description, amount, type, category, balance, fcy_amount, fcy_currency

The first 7 columns match the finance pipeline schema and are pipeline-compatible.
fcy_amount and fcy_currency are supplementary — the pipeline ignores them but they
are preserved in source CSVs for foreign-spend analysis.

Date semantics:
  V1 (Feb–Aug 2025): posting date (only date available in PDF)
  V2 (Sep 2025+):    transaction date (when you actually spent; more accurate for
                     monthly attribution). Posting date is discarded in V2.

FCY transactions: SGD amount goes into the `amount` field. The original foreign
currency amount (e.g. 130.00) goes into `fcy_amount` and the ISO currency code
(e.g. MYR) goes into `fcy_currency`. The `description` field is kept clean.

Credit sub-types (all use type=credit; pipeline should categorise further):
  - "Cashback" — spending reward earned on the card
  - "Credit Payment from Trust savings account" — inter-account transfer (bill payment)
  - merchant refunds — name of original merchant, amount with + prefix in PDF

Handles two PDF layouts:
  V1 (Feb–Aug 2025): single "Posting date" column per row
  V2 (Sep 2025+):    "Transaction date" + "Posting date" columns per row

Usage:
  python3 extract_trust_bank_cc.py statement.pdf [output.csv]
  python3 extract_trust_bank_cc.py statement.pdf  # prints to stdout
"""

import csv
import re
import sys
from pathlib import Path

try:
    import fitz  # pymupdf
except ImportError:
    sys.exit("Error: pymupdf not installed. Run: pip install pymupdf")

MONTH_MAP = {
    "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
    "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12,
}

SECTION_HEADERS = {
    "Cashback credit card",
    "Link credit card",
    "Loans, Fees, Charges and Repayments",
}

SKIP_DESCRIPTIONS = {"Previous balance", "Total outstanding balance"}

_DATE = re.compile(r"^\d{1,2} (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)$")
_SGD_AMOUNT = re.compile(r"^[+-]?[\d,]+\.\d{2}$")
_EXCHANGE_RATE = re.compile(r"^\d+ \w+ = [\d.]+ SGD$")
_FCY_AMOUNT = re.compile(r"^[\d,]+\.\d{2} [A-Z]{3}$")


def _is_date(line: str) -> bool:
    return bool(_DATE.match(line))


def _is_sgd_amount(line: str) -> bool:
    return bool(_SGD_AMOUNT.match(line))


def _is_exchange_rate(line: str) -> bool:
    return bool(_EXCHANGE_RATE.match(line))


def _clean_lines(raw_text: str) -> list[str]:
    """Strip whitespace and non-breaking spaces; drop empty lines."""
    lines = []
    for line in raw_text.split("\n"):
        line = line.replace("\xa0", " ").strip()
        if line:
            lines.append(line)
    return lines


def _extract_cycle(page1_text: str) -> tuple[int, int, int, int]:
    """Return (start_month, start_year, end_month, end_year) from Statement cycle."""
    # Collapse newlines so split years (e.g. "18 Dec\n2025") are joined
    text = page1_text.replace("\n", " ")
    m = re.search(
        r"Statement cycle\s+(\d+)\s+(\w+)\s+(\d{4})\s+-\s+(\d+)\s+(\w+)\s+(\d{4})",
        text,
    )
    if not m:
        raise ValueError("Could not find statement cycle on page 1")
    start_mon, start_year = m.group(2), int(m.group(3))
    end_mon, end_year = m.group(5), int(m.group(6))
    return MONTH_MAP[start_mon], start_year, MONTH_MAP[end_mon], end_year


def _assign_year(
    date_str: str,
    start_month: int,
    start_year: int,
    end_month: int,
    end_year: int,
) -> int:
    """Resolve the calendar year for a 'DD Mon' date within the statement cycle."""
    month_num = MONTH_MAP[date_str.strip().split()[1]]
    if start_year == end_year:
        return start_year
    # Cross-year cycle: start_month > end_month (e.g. Dec → Jan)
    return start_year if month_num >= start_month else end_year


def _parse_date(date_str: str, year: int) -> str:
    """Convert 'DD Mon' to 'YYYY-MM-DD'."""
    day, mon = date_str.strip().split()
    return f"{year}-{MONTH_MAP[mon]:02d}-{int(day):02d}"


def _detect_format_v2(doc) -> bool:
    """Return True when the statement uses the two-date-column V2 layout."""
    if len(doc) < 2:
        return False
    return "Transaction\ndate\nPosting date" in doc[1].get_text()


def _parse_page(
    lines: list[str],
    format_v2: bool,
    start_month: int,
    start_year: int,
    end_month: int,
    end_year: int,
) -> list[dict]:
    """Extract transactions from cleaned lines of one transaction page."""
    transactions = []
    i = 0

    while i < len(lines):
        line = lines[i]

        if line in SECTION_HEADERS:
            i += 1
            continue

        if not _is_date(line):
            i += 1
            continue

        # Consume date(s); after this block i points at the first description line
        if format_v2:
            txn_date = line  # transaction date (when you spent)
            i += 1
            if i >= len(lines) or not _is_date(lines[i]):
                continue  # expected posting date, not found
            i += 1  # skip posting date — now at first desc line
            date_to_use = txn_date
        else:
            date_to_use = line  # V1 only has posting date
            i += 1  # advance past date line — now at first desc line

        # Collect description lines; stop at amount, exchange rate, date, or section header
        desc_lines = []
        while i < len(lines):
            l = lines[i]
            if (
                _is_sgd_amount(l)
                or _is_exchange_rate(l)
                or _is_date(l)
                or l in SECTION_HEADERS
            ):
                break
            desc_lines.append(l)
            i += 1

        desc = " ".join(desc_lines).strip()
        if not desc:
            continue

        if desc in SKIP_DESCRIPTIONS:
            if i < len(lines) and _is_sgd_amount(lines[i]):
                i += 1
            continue

        # Capture FCY data into structured fields (description stays clean)
        fcy_amount = ""
        fcy_currency = ""
        if i < len(lines) and _is_exchange_rate(lines[i]):
            i += 1  # skip "1 XXX = N.NNNN SGD"
            if i < len(lines) and _FCY_AMOUNT.match(lines[i]):
                parts = lines[i].split()  # e.g. ["130.00", "MYR"]
                fcy_amount = parts[0].replace(",", "")
                fcy_currency = parts[1]
                i += 1

        if i >= len(lines) or not _is_sgd_amount(lines[i]):
            continue

        amount_str = lines[i]
        i += 1

        is_credit = amount_str.startswith("+")
        amount = float(amount_str.lstrip("+").replace(",", ""))
        year = _assign_year(date_to_use, start_month, start_year, end_month, end_year)
        date = _parse_date(date_to_use, year)

        transactions.append({
            "date": date,
            "account": "Trust Bank",
            "description": desc,
            "amount": amount,
            "type": "credit" if is_credit else "debit",
            "category": "",
            "balance": "",
            "fcy_amount": fcy_amount,
            "fcy_currency": fcy_currency,
        })

    return transactions


def extract_transactions(pdf_path: str) -> list[dict]:
    doc = fitz.open(pdf_path)

    page1_text = doc[0].get_text()
    start_month, start_year, end_month, end_year = _extract_cycle(page1_text)
    format_v2 = _detect_format_v2(doc)

    transactions = []
    for page_num in range(1, len(doc)):
        raw = doc[page_num].get_text()
        lines = _clean_lines(raw)

        try:
            start = lines.index("Amount in SGD") + 1
        except ValueError:
            continue

        page_txns = _parse_page(
            lines[start:], format_v2, start_month, start_year, end_month, end_year
        )
        transactions.extend(page_txns)

    return transactions


def write_csv(transactions: list[dict], output_path: str | None = None) -> None:
    fieldnames = [
        "date", "account", "description", "amount", "type", "category", "balance",
        "fcy_amount", "fcy_currency",  # supplementary; ignored by pipeline, useful for analysis
    ]
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
            write_csv([], output_path)
    else:
        write_csv(transactions, output_path)

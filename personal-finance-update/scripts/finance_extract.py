#!/usr/bin/env python3
"""
Extract personal finance data from master CSVs and output JSON
for Obsidian table generation.

Usage:
  python3 finance_extract.py
"""

import csv
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

_CONFIG_PATH = Path(__file__).parent.parent / "config.json"


def load_config():
  with open(_CONFIG_PATH) as f:
    return json.load(f)


config = load_config()
MASTER_DIR = Path(config["master_dir"])
VALIDATOR = config["validator"]

NECESSITIES = {
  "Groceries", "Transport", "Bills & GIRO", "Insurance",
  "Health & Fitness", "Fees & Charges", "Education",
}
LUXURIES = {
  "Food & Dining", "Shopping", "Entertainment", "Travel", "Subscriptions",
}
EXCLUDED_NL = {"Transfer", "Income & Credits", "Cash Withdrawal"}

EXCLUDED_TREND = {"Transfer", "Income & Credits", "Uncategorized"}
EXCLUDED_BREAKDOWN = {"Transfer", "Cash Withdrawal", "Income & Credits"}


def load_csv(year):
  path = MASTER_DIR / f"{year}_master.csv"
  if not path.exists():
    return None
  with open(path, newline="") as f:
    return list(csv.DictReader(f))


def discover_years():
  years = []
  for p in MASTER_DIR.glob("*_master.csv"):
    m = re.match(r"^(\d{4})_master\.csv$", p.name)
    if m:
      years.append(int(m.group(1)))
  return sorted(years)


def compute_totals(rows):
  total_debits = 0.0
  total_credits = 0.0
  for r in rows:
    amt = float(r["amount"])
    if r["type"] == "debit":
      total_debits += amt
    elif r["type"] == "credit":
      total_credits += amt
  return total_debits, total_credits


def count_distinct_months(rows):
  return len(set(r["date"][:7] for r in rows))


def build_yearly_overview(all_data):
  overview = []
  for year in sorted(all_data.keys()):
    rows = all_data[year]
    total_debits, total_credits = compute_totals(rows)
    net = round(total_credits - total_debits, 2)
    overview.append({
      "year": year,
      "total_debits": round(total_debits, 2),
      "total_credits": round(total_credits, 2),
      "net": net,
      "txn_count": len(rows),
      "partial": count_distinct_months(rows) < 12,
    })
  return overview


def find_breakdown_year(all_data):
  """Latest full year (12 distinct months). Fall back to previous year."""
  years = sorted(all_data.keys(), reverse=True)
  for y in years:
    if count_distinct_months(all_data[y]) >= 12:
      return y
  return years[0] if years else None


def build_category_breakdown(rows, year):
  debit_by_cat = defaultdict(float)
  debit_count_by_cat = defaultdict(int)
  total_debits = 0.0

  for r in rows:
    if r["type"] != "debit":
      continue
    amt = float(r["amount"])
    cat = r["category"]
    debit_by_cat[cat] += amt
    debit_count_by_cat[cat] += 1
    total_debits += amt

  transfer_total = round(debit_by_cat.get("Transfer", 0), 2)
  cash_total = round(debit_by_cat.get("Cash Withdrawal", 0), 2)
  categorised_spend = round(total_debits - transfer_total - cash_total, 2)

  result_rows = []
  for cat, amt in debit_by_cat.items():
    if cat in EXCLUDED_BREAKDOWN or amt == 0:
      continue
    pct = round(amt / categorised_spend * 100, 1) if categorised_spend else 0
    result_rows.append({
      "category": cat,
      "amount": round(amt, 2),
      "pct": pct,
      "txns": debit_count_by_cat[cat],
    })

  result_rows.sort(key=lambda r: r["amount"], reverse=True)

  return {
    "year": year,
    "rows": result_rows,
    "total_debits": round(total_debits, 2),
    "transfer_total": transfer_total,
    "cash_total": cash_total,
    "categorised_spend": categorised_spend,
  }


def build_spending_trend(all_data):
  trend_years = sorted(y for y in all_data if y >= 2022)
  cat_totals = defaultdict(lambda: defaultdict(float))

  for y in trend_years:
    for r in all_data[y]:
      if r["type"] != "debit":
        continue
      cat = r["category"]
      if cat in EXCLUDED_TREND:
        continue
      cat_totals[cat][y] += float(r["amount"])

  # Filter out categories with all zeros across trend years
  active_cats = {
    cat for cat, yearly in cat_totals.items()
    if any(yearly[y] > 0 for y in trend_years)
  }

  # Sort by max value descending
  sorted_cats = sorted(
    active_cats,
    key=lambda c: max(cat_totals[c][y] for y in trend_years),
    reverse=True,
  )

  categories = []
  for cat in sorted_cats:
    values = [round(cat_totals[cat][y], 2) for y in trend_years]
    categories.append({"category": cat, "values": values})

  return {"years": trend_years, "categories": categories}


def build_necessities_luxuries(all_data):
  result = []
  for year in sorted(y for y in all_data if y >= 2020):
    rows = all_data[year]
    totals = {"necessities": 0.0, "luxuries": 0.0, "business": 0.0, "investment": 0.0}
    total_debits = 0.0

    for r in rows:
      if r["type"] != "debit":
        continue
      amt = float(r["amount"])
      cat = r["category"]
      total_debits += amt

      if cat in NECESSITIES:
        totals["necessities"] += amt
      elif cat in LUXURIES:
        totals["luxuries"] += amt
      elif cat == "Business":
        totals["business"] += amt
      elif cat == "Investment":
        totals["investment"] += amt

    result.append({
      "year": year,
      "necessities": round(totals["necessities"], 2),
      "luxuries": round(totals["luxuries"], 2),
      "business": round(totals["business"], 2),
      "investment": round(totals["investment"], 2),
      "total_debits": round(total_debits, 2),
    })
  return result


def parse_validator_output(output):
  """Parse validator stdout into status, pass/warn/fail counts, and notes."""
  passes = output.count("[PASS]")
  warnings = output.count("[WARN]")
  failures = output.count("[FAIL]")

  status = "PASS"
  summary_match = re.search(r"overall (\w+)", output)
  if summary_match:
    status = summary_match.group(1)

  notes = extract_warning_notes(output)
  return status, passes, warnings, failures, notes


def extract_warning_notes(output):
  """Extract key warning details into a compact comma-separated string."""
  notes = []

  m = re.search(r"Uncategorized transactions.*?(\d+) row\(s\),\s*total \$([0-9,.]+)", output)
  if m:
    amt = m.group(2).replace(",", "")
    notes.append(f"{m.group(1)} uncategorized (${amt})")
  else:
    m = re.search(r"Uncategorized transactions.*?(\d+) row", output)
    if m:
      notes.append(f"{m.group(1)} uncategorized")

  m = re.search(r"Zero-amount rows.*?(\d+) row", output)
  if m:
    notes.append(f"{m.group(1)} zero-amount")

  m = re.search(r"Month coverage: (\d+)/12", output)
  if m and int(m.group(1)) < 12:
    notes.append(f"{m.group(1)}/12 months")

  for line in output.split("\n"):
    if "Category distribution" in line and "WARN" in line:
      m = re.search(r'"([^"]+)" is ([0-9.]+)%', line)
      if m and m.group(1) != "Transfer":
        notes.append(f"single-category skew ({m.group(1)} {m.group(2)}%)")
      break

  m = re.search(r"Large transactions.*?(\d+) transaction", output)
  if m:
    notes.append(f"{m.group(1)} large txns")

  if "Transfer balance" in output and "missed pairs" in output:
    notes.append("transfer imbalance")

  m = re.search(r"Empty/short descriptions.*?(\d+) row", output)
  if m:
    notes.append(f"{m.group(1)} short descriptions")

  return ", ".join(notes)


def run_validator(year):
  """Run validate_master.py for a single year, parse output."""
  try:
    proc = subprocess.run(
      ["python3", VALIDATOR, str(year)],
      capture_output=True, text=True, timeout=30,
    )
    output = proc.stdout + proc.stderr
    return parse_validator_output(output)
  except (subprocess.TimeoutExpired, FileNotFoundError) as e:
    return "FAIL", 0, 0, 1, str(e)


def build_validation(years):
  results = []
  for year in sorted(years):
    status, passes, warnings, failures, notes = run_validator(year)
    results.append({
      "year": year,
      "status": status,
      "passes": passes,
      "warnings": warnings,
      "notes": notes,
    })
  return results


def main():
  try:
    years = discover_years()
    if not years:
      print("No master CSV files found", file=sys.stderr)
      sys.exit(1)

    all_data = {}
    for y in years:
      rows = load_csv(y)
      if rows:
        all_data[y] = rows

    breakdown_year = find_breakdown_year(all_data)
    if breakdown_year is None:
      print("No valid year for category breakdown", file=sys.stderr)
      sys.exit(1)

    output = {
      "yearly_overview": build_yearly_overview(all_data),
      "category_breakdown": build_category_breakdown(
        all_data[breakdown_year], breakdown_year
      ),
      "spending_trend": build_spending_trend(all_data),
      "necessities_luxuries": build_necessities_luxuries(all_data),
      "validation": build_validation(all_data.keys()),
    }

    print(json.dumps(output, indent=2))
    sys.exit(0)

  except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
  main()

#!/usr/bin/env python3
"""
Compare extracted finance JSON against Obsidian markdown tables.
Outputs a structured diff as JSON to stdout.

Usage:
  python3 finance_diff.py <json_path> <obsidian_note_path>
"""

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path

TABLE_ANCHORS = {
  "yearly_overview": "Yearly Overview",
  "category_breakdown": "Category Breakdown",
  "spending_trend": "Spending Categories",
  "necessities_luxuries": "Necessities vs Luxuries",
  "validation": "Validation Results",
}


def parse_args():
  parser = argparse.ArgumentParser(
    description="Diff finance JSON against Obsidian tables"
  )
  parser.add_argument("json_path", type=Path, help="Path to extract JSON")
  parser.add_argument("obsidian_path", type=Path, help="Path to Obsidian note")
  return parser.parse_args()


def read_file(path):
  if not path.exists():
    print(f"File not found: {path}", file=sys.stderr)
    sys.exit(1)
  return path.read_text(encoding="utf-8")


def find_section(lines, anchor):
  """Find section boundaries for a ### heading containing anchor."""
  start = None
  for i, line in enumerate(lines):
    if line.startswith("###") and anchor in line:
      start = i
      break
  if start is None:
    return None

  end = len(lines)
  for i in range(start + 1, len(lines)):
    if lines[i].startswith("###"):
      end = i
      break

  return start, end


def extract_table_block(lines, start, end):
  """Extract preamble, table rows, and postscript from a section."""
  heading = lines[start]
  table_start = None
  table_end = None

  for i in range(start + 1, end):
    if lines[i].startswith("|"):
      if table_start is None:
        table_start = i
      table_end = i
    elif table_start is not None and not lines[i].startswith("|"):
      break

  if table_start is None:
    return heading, "", [], ""

  preamble = "\n".join(lines[start + 1:table_start])
  table_lines = lines[table_start:table_end + 1]
  postscript = "\n".join(lines[table_end + 1:end])

  return heading, preamble, table_lines, postscript


def parse_md_table(table_lines):
  """Parse markdown table lines into headers and row dicts."""
  if len(table_lines) < 3:
    return [], []

  headers = [h.strip() for h in table_lines[0].split("|")[1:-1]]
  rows = []
  for line in table_lines[2:]:
    cells = [c.strip() for c in line.split("|")[1:-1]]
    row = {}
    for j, h in enumerate(headers):
      row[h] = cells[j] if j < len(cells) else ""
    rows.append(row)
  return headers, rows


def strip_numeric(val):
  """Strip formatting chars for numeric comparison."""
  val = val.replace("S$", "").replace("$", "")
  return re.sub(r"[,+%~]", "", val).strip()


def is_numeric(val):
  """Check if a stripped value is numeric."""
  try:
    float(strip_numeric(val))
    return True
  except (ValueError, TypeError):
    return False


def values_match(old_val, new_val, is_pct=False):
  """Compare two cell values with tolerance."""
  old_s = strip_numeric(old_val)
  new_s = strip_numeric(new_val)

  if not is_numeric(old_val) or not is_numeric(new_val):
    return old_val.strip() == new_val.strip()

  old_n = float(old_s)
  new_n = float(new_s)
  tolerance = 0.05 if is_pct else 1.0
  return abs(old_n - new_n) <= tolerance


def fmt_int(val):
  """Format a number as integer with commas."""
  return f"{round(val):,}"


def fmt_net(val):
  """Format net value with +/- prefix."""
  rounded = round(val)
  if rounded >= 0:
    return f"+{rounded:,}"
  return f"{rounded:,}"


def fmt_pct(val):
  """Format as percentage with one decimal."""
  return f"{val:.1f}%"


# --- Table builders ---

def build_yearly_overview_table(data, existing_notes):
  """Build yearly overview markdown table from JSON data."""
  headers = ["Year", "Total Debits", "Total Credits", "Net", "Txn Count", "Notes"]
  rows_md = []
  for row in data:
    year = str(row["year"])
    notes = existing_notes.get(year, "")
    if not notes and row.get("partial"):
      notes = "Partial year"
    rows_md.append(
      f"| {year} | {fmt_int(row['total_debits'])} "
      f"| {fmt_int(row['total_credits'])} "
      f"| {fmt_net(row['net'])} "
      f"| {row['txn_count']:,} "
      f"| {notes} |"
    )
  header_line = "| " + " | ".join(headers) + " |"
  sep_line = "|" + "|".join("------" for _ in headers) + "|"
  return "\n".join([header_line, sep_line] + rows_md)


def build_category_breakdown_table(data):
  """Build category breakdown markdown table from JSON data."""
  headers = ["Category", "Amount (S$)", "% of Categorised Spend", "Txns"]
  rows_md = []
  for row in data["rows"]:
    rows_md.append(
      f"| {row['category']} | {fmt_int(row['amount'])} "
      f"| {fmt_pct(row['pct'])} | {row['txns']} |"
    )
  header_line = "| " + " | ".join(headers) + " |"
  sep_line = "|" + "|".join("------" for _ in headers) + "|"
  return "\n".join([header_line, sep_line] + rows_md)


def build_category_breakdown_preamble(data):
  """Generate the preamble for category breakdown."""
  total = fmt_int(data["total_debits"])
  transfer = fmt_int(data["transfer_total"])
  cash = fmt_int(data["cash_total"])
  categorised = fmt_int(data["categorised_spend"])
  return (
    f"\nTotal tracked debits: S${total}. "
    f"Excluding transfers (S${transfer}) and cash (S${cash}), "
    f"**true categorised spend: S${categorised}**.\n"
  )


def build_spending_trend_table(data):
  """Build spending trend markdown table from JSON data."""
  years = data["years"]
  headers = ["Category"] + [str(y) for y in years]
  rows_md = []
  for cat in data["categories"]:
    vals = [fmt_int(v) if v != 0 else "0" for v in cat["values"]]
    row_cells = [cat["category"]] + vals
    rows_md.append("| " + " | ".join(row_cells) + " |")
  header_line = "| " + " | ".join(headers) + " |"
  sep_line = "|" + "|".join("------" for _ in headers) + "|"
  return "\n".join([header_line, sep_line] + rows_md)


def build_nl_table(data):
  """Build necessities vs luxuries markdown table from JSON data."""
  headers = [
    "Year", "Necessities (S$)", "Luxuries (S$)",
    "Business (S$)", "Investment (S$)", "Total Debits (S$)",
  ]
  rows_md = []
  for row in data:
    vals = [
      str(row["year"]),
      fmt_int(row["necessities"]),
      fmt_int(row["luxuries"]),
      fmt_int(row["business"]) if row["business"] != 0 else "0",
      fmt_int(row["investment"]) if row["investment"] != 0 else "0",
      fmt_int(row["total_debits"]),
    ]
    rows_md.append("| " + " | ".join(vals) + " |")
  header_line = "| " + " | ".join(headers) + " |"
  sep_line = "|" + "|".join("------" for _ in headers) + "|"
  return "\n".join([header_line, sep_line] + rows_md)


def build_validation_table(data):
  """Build validation results markdown table from JSON data."""
  headers = ["Year", "Result", "Passes", "Warnings", "Notes"]
  rows_md = []
  for row in data:
    rows_md.append(
      f"| {row['year']} | {row['status']} "
      f"| {row['passes']} | {row['warnings']} "
      f"| {row['notes']} |"
    )
  header_line = "| " + " | ".join(headers) + " |"
  sep_line = "|" + "|".join("------" for _ in headers) + "|"
  return "\n".join([header_line, sep_line] + rows_md)


def build_validation_preamble(data):
  """Generate the preamble for validation results."""
  years = [r["year"] for r in data]
  count = len(years)
  min_y = min(years)
  max_y = max(years)
  fail_count = sum(1 for r in data if r["status"] == "FAIL")
  if fail_count == 0:
    return (
      f"\nAll {count} master files ({min_y}\u2013{max_y}) pass with "
      f"**0 failures**. Remaining warnings are expected "
      f"given partial early-year data.\n"
    )
  return (
    f"\n{count} master files ({min_y}\u2013{max_y}) validated: "
    f"**{fail_count} failure(s)**. Review failing years below.\n"
  )


# --- Extract existing notes column ---

def extract_notes_column(table_lines, key_col="Year"):
  """Extract a dict of key -> Notes value from existing table."""
  headers, rows = parse_md_table(table_lines)
  if "Notes" not in headers:
    return {}
  notes = {}
  for row in rows:
    key = row.get(key_col, "").strip()
    notes[key] = row.get("Notes", "").strip()
  return notes


# --- Diff logic ---

def diff_table(old_headers, old_rows, new_table_str, table_key):
  """Compare old parsed rows against new table string. Return changes."""
  new_lines = new_table_str.strip().split("\n")
  new_headers, new_rows = parse_md_table(new_lines)

  changes = []
  pct_cols = {h for h in new_headers if "%" in h}

  # Build lookup by first column (row key)
  old_by_key = {}
  for row in old_rows:
    key = row.get(old_headers[0], "") if old_headers else ""
    old_by_key[key] = row

  for new_row in new_rows:
    row_key = new_row.get(new_headers[0], "") if new_headers else ""
    old_row = old_by_key.get(row_key)

    for col in new_headers[1:]:
      new_val = new_row.get(col, "")
      if old_row is None:
        changes.append({
          "table": table_key,
          "row": row_key,
          "col": col,
          "old": "(new row)",
          "new": new_val,
        })
        continue

      old_val = old_row.get(col, "")
      is_pct = col in pct_cols
      if not values_match(old_val, new_val, is_pct):
        changes.append({
          "table": table_key,
          "row": row_key,
          "col": col,
          "old": old_val,
          "new": new_val,
        })

  # Check for removed rows
  new_keys = {r.get(new_headers[0], "") for r in new_rows} if new_headers else set()
  for key in old_by_key:
    if key not in new_keys:
      changes.append({
        "table": table_key,
        "row": key,
        "col": "(entire row)",
        "old": "(removed)",
        "new": "",
      })

  return changes


def process_yearly_overview(json_data, lines, section):
  """Process yearly overview table."""
  start, end = section
  heading, preamble, table_lines, postscript = extract_table_block(
    lines, start, end
  )
  old_headers, old_rows = parse_md_table(table_lines)
  existing_notes = extract_notes_column(table_lines)

  new_table = build_yearly_overview_table(
    json_data["yearly_overview"], existing_notes
  )
  changes = diff_table(
    old_headers, old_rows, new_table, "yearly_overview"
  )

  section_md = {
    "heading": heading,
    "preamble": preamble,
    "table": new_table,
    "postscript": postscript,
  }
  return changes, section_md


def process_category_breakdown(json_data, lines, section):
  """Process category breakdown table."""
  start, end = section
  heading, preamble, table_lines, postscript = extract_table_block(
    lines, start, end
  )
  old_headers, old_rows = parse_md_table(table_lines)
  data = json_data["category_breakdown"]

  new_heading = f"### {data['year']} Category Breakdown (Full Year)"
  new_preamble = build_category_breakdown_preamble(data)
  new_table = build_category_breakdown_table(data)
  changes = diff_table(
    old_headers, old_rows, new_table, "category_breakdown"
  )

  section_md = {
    "heading": new_heading,
    "preamble": new_preamble,
    "table": new_table,
    "postscript": postscript,
  }
  return changes, section_md


def process_spending_trend(json_data, lines, section):
  """Process spending trend table."""
  start, end = section
  heading, preamble, table_lines, postscript = extract_table_block(
    lines, start, end
  )
  old_headers, old_rows = parse_md_table(table_lines)
  data = json_data["spending_trend"]

  years = data["years"]
  min_y, max_y = min(years), max(years)
  new_heading = (
    f"### Top Spending Categories \u2014 Trend "
    f"({min_y}\u2013{max_y}, excl. Transfers & Cash)"
  )
  new_table = build_spending_trend_table(data)
  changes = diff_table(
    old_headers, old_rows, new_table, "spending_trend"
  )

  section_md = {
    "heading": new_heading,
    "preamble": preamble,
    "table": new_table,
    "postscript": postscript,
  }
  return changes, section_md


def process_necessities_luxuries(json_data, lines, section):
  """Process necessities vs luxuries table."""
  start, end = section
  heading, preamble, table_lines, postscript = extract_table_block(
    lines, start, end
  )
  old_headers, old_rows = parse_md_table(table_lines)
  data = json_data["necessities_luxuries"]

  years = [r["year"] for r in data]
  min_y, max_y = min(years), max(years)
  new_heading = (
    f"### Necessities vs Luxuries \u2014 Trend ({min_y}\u2013{max_y})"
  )
  new_table = build_nl_table(data)
  changes = diff_table(
    old_headers, old_rows, new_table, "necessities_luxuries"
  )

  section_md = {
    "heading": new_heading,
    "preamble": preamble,
    "table": new_table,
    "postscript": postscript,
  }
  return changes, section_md


def process_validation(json_data, lines, section):
  """Process validation results table."""
  start, end = section
  heading, preamble, table_lines, postscript = extract_table_block(
    lines, start, end
  )
  old_headers, old_rows = parse_md_table(table_lines)
  data = json_data["validation"]

  today = date.today().isoformat()
  new_heading = f"### Latest Validation Results ({today})"
  new_preamble = build_validation_preamble(data)
  new_table = build_validation_table(data)
  changes = diff_table(
    old_headers, old_rows, new_table, "validation"
  )

  section_md = {
    "heading": new_heading,
    "preamble": new_preamble,
    "table": new_table,
    "postscript": postscript,
  }
  return changes, section_md


PROCESSORS = {
  "yearly_overview": process_yearly_overview,
  "category_breakdown": process_category_breakdown,
  "spending_trend": process_spending_trend,
  "necessities_luxuries": process_necessities_luxuries,
  "validation": process_validation,
}


def main():
  args = parse_args()
  json_text = read_file(args.json_path)
  md_text = read_file(args.obsidian_path)

  try:
    json_data = json.loads(json_text)
  except json.JSONDecodeError as e:
    print(f"Invalid JSON: {e}", file=sys.stderr)
    sys.exit(1)

  lines = md_text.split("\n")

  all_changes = []
  tables_changed = []
  new_sections = {}

  for table_key, anchor in TABLE_ANCHORS.items():
    section = find_section(lines, anchor)
    if section is None:
      print(
        f"Warning: section '{anchor}' not found in note",
        file=sys.stderr,
      )
      continue

    if table_key not in json_data:
      print(
        f"Warning: key '{table_key}' not found in JSON",
        file=sys.stderr,
      )
      continue

    processor = PROCESSORS[table_key]
    changes, section_md = processor(json_data, lines, section)

    if changes:
      tables_changed.append(table_key)
      all_changes.extend(changes)
      new_sections[table_key] = section_md

  output = {
    "tables_changed": tables_changed,
    "cells_changed": len(all_changes),
    "changes": all_changes,
    "new_markdown_sections": new_sections,
  }

  print(json.dumps(output, indent=2))
  sys.exit(0)


if __name__ == "__main__":
  main()

#!/usr/bin/env python3
"""Convert scanned newspaper/magazine PDFs to Markdown using PyMuPDF + Tesseract OCR,
with optional Claude cleanup for readability.

Usage:
  python3 pdf_to_md.py <input.pdf> <output.md> [--no-cleanup]

Dependencies:
  - tesseract (brew install tesseract)
  - PyMuPDF (pip install pymupdf)
  - anthropic in ~/.venvs/marker (for cleanup step)
  - ANTHROPIC_API_KEY in environment
"""

import subprocess
import sys
import tempfile
from pathlib import Path

import fitz  # PyMuPDF

CLEANUP_MODEL = "claude-haiku-4-5-20251001"

CLEANUP_PROMPT = """\
You are cleaning up OCR text extracted from a newspaper page. The text has issues:
- Soft hyphens mid-word across line breaks (e.g. "infla-\\ntion" → "inflation")
- Random noise characters from photos, charts, and image areas
- Column text that may be interleaved or out of order
- Missing spaces or extra spaces from OCR errors

Your task:
1. Fix broken hyphenated words across line breaks.
2. Remove noise lines (gibberish, random symbols, lines of dashes/equals signs, very short fragments).
3. Separate distinct articles/sections with a blank line and a `###` heading if you can identify the headline.
4. Preserve all real content — do not summarize or omit any article text.
5. Output clean Markdown only. No commentary, no preamble.

Raw OCR text:
{text}"""


def ocr_page(page: fitz.Page, dpi: int = 300) -> str:
  mat = fitz.Matrix(dpi / 72, dpi / 72)
  pix = page.get_pixmap(matrix=mat)
  with tempfile.NamedTemporaryFile(suffix=".png", delete=True) as tmp:
    pix.save(tmp.name)
    result = subprocess.run(
      ["tesseract", tmp.name, "stdout", "--psm", "1", "-l", "eng"],
      capture_output=True, text=True
    )
  return result.stdout.strip()


def clean_page(text: str, client) -> str:
  message = client.messages.create(
    model=CLEANUP_MODEL,
    max_tokens=4096,
    messages=[{"role": "user", "content": CLEANUP_PROMPT.format(text=text)}],
  )
  return message.content[0].text.strip()


def pdf_to_markdown(pdf_path: str, output_path: str, dpi: int = 300, cleanup: bool = True) -> None:
  pdf_path = Path(pdf_path)
  doc = fitz.open(str(pdf_path))
  total_pages = len(doc)
  print(f"Processing: {pdf_path.name} ({total_pages} pages)")

  client = None
  if cleanup:
    try:
      import anthropic
      client = anthropic.Anthropic()
      print(f"  Cleanup enabled (model: {CLEANUP_MODEL})")
    except Exception as e:
      print(f"  Warning: Claude cleanup unavailable ({e}) — writing raw OCR")
      cleanup = False

  all_pages = []

  for page_num in range(total_pages):
    page = doc[page_num]
    raw_text = ocr_page(page, dpi)

    if not raw_text:
      print(f"  Page {page_num + 1}/{total_pages} — (no text detected)")
      continue

    if cleanup and client:
      try:
        text = clean_page(raw_text, client)
        print(f"  Page {page_num + 1}/{total_pages} — {len(raw_text)} → {len(text)} chars (cleaned)")
      except Exception as e:
        print(f"  Page {page_num + 1}/{total_pages} — cleanup failed ({e}), using raw OCR")
        text = raw_text
    else:
      text = raw_text
      print(f"  Page {page_num + 1}/{total_pages} — {len(text)} chars")

    all_pages.append(f"## Page {page_num + 1}\n\n{text}")

  doc.close()

  output = Path(output_path)
  with open(output, "w") as f:
    f.write(f"# {pdf_path.stem}\n\n")
    f.write("\n\n---\n\n".join(all_pages))

  print(f"Done: {output} ({len(all_pages)} pages)")


if __name__ == "__main__":
  if len(sys.argv) < 3:
    print("Usage: pdf_to_md.py <input.pdf> <output.md> [--no-cleanup]")
    sys.exit(1)
  no_cleanup = "--no-cleanup" in sys.argv
  pdf_to_markdown(sys.argv[1], sys.argv[2], cleanup=not no_cleanup)

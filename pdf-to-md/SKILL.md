---
name: pdf-to-md
description: "Convert scanned newspaper or magazine PDFs to readable Markdown using OCR + Claude cleanup. Use when user says 'convert PDF to markdown', 'extract text from newspaper PDF', 'read this PDF as markdown', or drops a newspaper PDF."
user-invocable: true
---

# PDF to Markdown

Convert scanned newspaper or magazine PDFs (FT, The Economist, etc.) to readable Markdown files using Tesseract OCR + Claude cleanup.

## Trigger

Use when the user says:
- "convert this PDF to markdown"
- "extract text from this newspaper PDF"
- "I have a new FT / Economist PDF"
- "read this PDF as a note"

## Usage

```bash
~/.venvs/marker/bin/python ~/.claude/skills/pdf-to-md/scripts/pdf_to_md.py \
  /path/to/newspaper.pdf \
  /path/to/output.md
```

Skip the Claude cleanup step (raw OCR only, faster):
```bash
~/.venvs/marker/bin/python ~/.claude/skills/pdf-to-md/scripts/pdf_to_md.py \
  /path/to/newspaper.pdf \
  /path/to/output.md \
  --no-cleanup
```

## Output location

Place output `.md` files in the vault at `00_inbox/` or `30_knowledge/` as appropriate.
Use `snake_case` filenames with ISO dates, e.g. `financial_times_uk_2026-03-27.md`.

## Dependencies

| Tool | Install |
|------|---------|
| tesseract | `brew install tesseract` |
| PyMuPDF | system Python (`pymupdf` already installed) |
| anthropic | `~/.venvs/marker` (already installed) |
| ANTHROPIC_API_KEY | must be set in environment |

## Notes

- Cleanup uses `claude-haiku-4-5-20251001` — fast and cheap (~seconds per page, cents per issue).
- Change `CLEANUP_MODEL` in the script to `claude-sonnet-4-6` for higher quality cleanup.
- Newspaper PDFs are scanned images — no text layer. OCR is required (pdftotext won't work).
- ~2-3 min per issue with cleanup enabled; ~30s without.

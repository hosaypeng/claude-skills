---
name: ocr
description: "OCR a scanned PDF or image locally with GLM-OCR (Ollama) and save the text as Markdown, without reading it into the conversation. Use when user says '/ocr', 'OCR this', 'extract text from this scan', 'read this scanned PDF', 'convert this image to text', or 'get the table out of this image'."
user-invocable: true
argument-hint: "<file> [text|table|formula] [pages 1-12] [output folder]"
---

# OCR

Run GLM-OCR on this Mac through Ollama. Page images never leave the machine. The script writes the result to a Markdown file and prints only a summary, so the text stays out of the conversation.

## Instructions

1. Take the file path from the arguments. If none was given, ask for one.
2. Pick the mode:
   - `text` (default) for ordinary pages.
   - `table` when the image or page is entirely a table: a screenshot or crop of one, a statement page or a spreadsheet. It returns an HTML `<table>`. On a mixed page of text plus a table, it reads the text and skips the table (tested). Use `text` there, or crop the table first.
   - `formula` for maths.
3. Run the script with `run_in_background: true`. The Bash tool's 2-minute default timeout is shorter than a 3-page run. Add `-p` only for a page range, and `-o` only when the user names an output folder:

```bash
bash ~/.claude/skills/ocr/scripts/ocr.sh -m <mode> [-p 1-12] [-o <folder>] "<file>"
```

   - Default output: `~/Documents/obsidian/00_inbox/<name>_ocr.md`.
   - Private sources (under `~/Sync/` or a `personal_records` folder) never go into the vault, because it auto-pushes to GitHub.
     - Under `~/Sync/`, the output goes next to the source.
     - Anywhere else, the script stops and asks for `-o`. Ask the user where to write. Never suggest the vault or the Google Drive mirror.
   - It never overwrites an existing file.
   - It starts its own Ollama server on `127.0.0.1:11435` with a 16k context and stops it on exit. Ollama's default 4k context cuts every page off after about a paragraph.
   - Expect about 20 seconds to load the model, then roughly 40 seconds per dense page on an M3 with 16 GB (11 pages took about 7 minutes).
4. When the background task finishes, report the summary lines as printed.

## Privacy Rules

- Do not Read, cat or grep the output file unless the user asks. Reading it sends the text to Anthropic; say so first when the source is private.
- Don't run `pdfinfo` on a private file without `| grep '^Pages:'`, because its Title and Author fields can name people.
- Never run `ollama pull`, or `ollama run` with a model that isn't installed (it downloads automatically).
- Don't start Ollama as a login service (`brew services start ollama`).

## Troubleshooting

- **"model 'glm-ocr' is not installed"**: the user downloads it (2.7 GB) by running `ollama serve` in a separate Terminal window, then `ollama pull glm-ocr` in another, then stopping the server with Ctrl-C.
- **"something is already serving on 127.0.0.1:11435"**: another `/ocr` run is in progress, or an earlier run was killed and left its server behind. Check with `lsof -i :11435`. Wait for the other run, or ask the user before stopping that process.
- **"could not render the PDF"**: the PDF is password-protected or damaged, or the `-p` range starts past the last page. Check the page count with `pdfinfo "<file>" | grep '^Pages:'`.
- **Gaps in the output**:
  - Pages marked `TRUNCATED`: usually the model got stuck repeating itself. Re-run those pages with `-p`.
  - Tables missing from mixed pages: Ollama runs the model without GLM-OCR's separate layout step. Crop the table (`pdftoppm -x -y -W -H`) and run `-m table` on the crop.
  - "did not attach the image": Ollama didn't recognise the page path. Check `ollama --version` and report it.

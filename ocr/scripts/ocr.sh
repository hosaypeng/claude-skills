#!/bin/bash
set -e

# OCR a PDF or image locally with GLM-OCR (via Ollama) and save it as Markdown.
# Usage: ocr.sh [-m text|table|formula] [-p first[-last]] [-o output_dir] <file>
# Prints only a summary (path, pages, characters, time), never the text itself.
# Output goes to the vault inbox by default. Private sources (under ~/Sync/ or a
# personal_records folder) go next to the source when it is under ~/Sync/,
# otherwise need -o, and are never written into the vault, which auto-pushes.

# --- Settings ---
MODEL="${OCR_MODEL:-glm-ocr}"
OLLAMA="/opt/homebrew/opt/ollama/bin/ollama"
PDFTOPPM="/opt/homebrew/bin/pdftoppm"
VAULT="$HOME/Documents/obsidian"
INBOX="$VAULT/00_inbox"
SYNC="$HOME/Sync"
DPI=200
# Ollama's default 4096-token context is used up by a 200 dpi page image alone,
# so run a private server with a larger context on its own port
CTX=16384
export OLLAMA_HOST="127.0.0.1:11435"

mode="text"
pages=""
first=""
last=""
out_dir=""
work_dir=""
server_pid=""
private=0
is_pdf=0
empty=0
truncated=""
range_note=""

# --- Helpers ---
die() {
  echo "Error: $*" >&2
  exit 1
}

usage() {
  echo "Usage: ocr.sh [-m text|table|formula] [-p first[-last]] [-o output_dir] <file>" >&2
  exit 1
}

# Stop the server this script started, and remove the page images
cleanup() {
  if [ -n "$server_pid" ]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  if [ -n "$work_dir" ] && [ -d "$work_dir" ]; then
    rm -rf "$work_dir"
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# True when folder $1 is $2 or inside it. -ef compares the folders themselves,
# so symlinks, firmlinks (/System/Volumes/Data) and letter case don't matter.
is_within() {
  local d="$1"
  [ -e "$2" ] || return 1
  while true; do
    if [ "$d" -ef "$2" ]; then return 0; fi
    if [ "$d" = "/" ]; then return 1; fi
    d=$(dirname "$d")
  done
}

# A folder is private when it is inside ~/Sync/ or any personal_records folder
is_private() {
  local lower
  if is_within "$1" "$SYNC"; then return 0; fi
  lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$lower/" in
    */personal_records/*) return 0 ;;
  esac
  return 1
}

# snake_case stem of a filename, falling back to "ocr_output"
to_stem() {
  local stem
  stem=$(printf '%s' "${1%.*}" | tr '[:upper:]' '[:lower:]' \
    | LC_ALL=C sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//')
  echo "${stem:-ocr_output}"
}

# --- Arguments ---
while getopts "m:p:o:h" opt; do
  case "$opt" in
    m) mode="$OPTARG" ;;
    p) pages="$OPTARG" ;;
    o) out_dir="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || usage
input="$1"

case "$mode" in
  text) prompt="Text Recognition:" ;;
  table) prompt="Table Recognition:" ;;
  formula) prompt="Formula Recognition:" ;;
  *) die "unknown mode '$mode' (use text, table or formula)" ;;
esac

if [ -n "$pages" ]; then
  [[ "$pages" =~ ^([0-9]+)(-([0-9]+))?$ ]] || die "pages must look like 5 or 1-12"
  first="${BASH_REMATCH[1]}"
  last="${BASH_REMATCH[3]:-$first}"
  [ "$first" -le "$last" ] || die "page range runs backwards: $pages"
fi

# --- Paths ---
check_tools() {
  [ -x "$OLLAMA" ] || die "Ollama not found at $OLLAMA (brew install ollama)"
  [ -x "$PDFTOPPM" ] || die "pdftoppm not found at $PDFTOPPM (brew install poppler)"
  local tool
  for tool in sips file realpath; do
    command -v "$tool" >/dev/null || die "$tool not found"
  done
}

# Check both the path as given and the real file behind any symlink
resolve_source() {
  [ -f "$input" ] || die "file not found: $input"
  src_dir=$(cd "$(dirname "$input")" && pwd)
  src_name=$(basename "$input")
  src_path="$src_dir/$src_name"
  real_dir=$(dirname "$(realpath "$input")")
  if is_private "$src_dir" || is_private "$real_dir"; then
    private=1
  fi
  if [ "$(file -b --mime-type "$src_path")" = "application/pdf" ]; then
    is_pdf=1
  fi
  if [ "$is_pdf" -eq 0 ] && [ -n "$pages" ]; then
    die "-p only applies to PDFs"
  fi
}

resolve_dest() {
  if [ -z "$out_dir" ]; then
    if [ "$private" -eq 0 ]; then
      out_dir="$INBOX"
    elif is_within "$real_dir" "$SYNC"; then
      out_dir="$src_dir"
    else
      die "private source outside ~/Sync/; pass -o with the folder to write to"
    fi
  fi
  [ -d "$out_dir" ] || die "output folder not found: $out_dir"
  out_dir=$(cd "$out_dir" && pwd -P)
  if [ "$private" -eq 1 ] && is_within "$out_dir" "$VAULT"; then
    die "refusing to write a private source into the vault (it auto-pushes to GitHub); pass -o with another folder"
  fi
  out_file="$out_dir/$(to_stem "$src_name")_ocr.md"
  [ ! -e "$out_file" ] || die "output already exists, not overwriting: $out_file"
}

# --- Ollama ---
# Always start a fresh server, so its context size is known and it can be stopped
ensure_server() {
  if "$OLLAMA" list >/dev/null 2>&1; then
    die "something is already serving on $OLLAMA_HOST (another /ocr run, or a leftover server: lsof -i :11435)"
  fi
  # OLLAMA_NO_CLOUD: without it the server connects to ollama.com during runs
  OLLAMA_NO_CLOUD=1 OLLAMA_CONTEXT_LENGTH="$CTX" OLLAMA_FLASH_ATTENTION=1 \
    OLLAMA_KV_CACHE_TYPE=q8_0 "$OLLAMA" serve >/dev/null 2>&1 &
  server_pid=$!
  local tries=0
  while [ "$tries" -lt 40 ]; do
    sleep 0.5
    if "$OLLAMA" list >/dev/null 2>&1; then
      return 0
    fi
    tries=$((tries + 1))
  done
  die "Ollama server did not start within 20 seconds"
}

# `ollama run` downloads a missing model by itself, so refuse before that can happen
check_model() {
  "$OLLAMA" show "$MODEL" >/dev/null 2>&1 \
    || die "model '$MODEL' is not installed; download it yourself (see the skill's Troubleshooting)"
}

# --- Pages ---
# Render each page to a safely named PNG so Ollama reliably detects the image path
render_pages() {
  work_dir=$(mktemp -d -t ocr)
  local range=() wanted
  if [ "$is_pdf" -eq 1 ]; then
    if [ -n "$first" ]; then range=(-f "$first" -l "$last"); fi
    "$PDFTOPPM" -r "$DPI" -png "${range[@]}" "$src_path" "$work_dir/page" 2>/dev/null \
      || die "could not render the PDF (password-protected, damaged, or pages out of range?)"
  else
    sips -s format png "$src_path" --out "$work_dir/page-1.png" >/dev/null 2>&1 \
      || die "could not read the image (unsupported format?)"
  fi
  page_count=$(ls "$work_dir"/page-*.png 2>/dev/null | wc -l | tr -d ' ')
  [ "$page_count" -gt 0 ] || die "no pages rendered"
  if [ -n "$first" ]; then
    wanted=$((last - first + 1))
    if [ "$page_count" -lt "$wanted" ]; then
      range_note="only $page_count of the $wanted requested pages exist"
    fi
  fi
}

# Tokens used by one run (prompt + output), read from `ollama run --verbose` stats
tokens_used() {
  local prompt_n eval_n
  prompt_n=$(grep -o 'prompt eval count: *[0-9]*' "$1" | grep -o '[0-9]*$' | tail -1)
  eval_n=$(grep -v 'prompt eval count' "$1" | grep -o 'eval count: *[0-9]*' | grep -o '[0-9]*$' | tail -1)
  [ -n "$prompt_n" ] && [ -n "$eval_n" ] \
    || die "could not read token counts from Ollama; nothing written"
  echo $((prompt_n + eval_n))
}

ocr_pages() {
  tmp_md="$work_dir/out.md"
  local err="$work_dir/stderr.txt" page_txt="$work_dir/page.txt" img num label used
  printf '<!-- OCR: %s, %s mode, from %s on %s -->\n' \
    "$MODEL" "$mode" "$src_name" "$(date +%F)" > "$tmp_md"
  for img in "$work_dir"/page-*.png; do
    num="${img##*-}"
    num=$((10#${num%.png}))
    "$OLLAMA" run --verbose --nowordwrap "$MODEL" "$prompt $img" < /dev/null > "$page_txt" 2> "$err" \
      || die "Ollama failed on page $num; nothing written"
    grep -q "Added image" "$err" \
      || die "Ollama did not attach the image for page $num; nothing written"
    label="page $num"
    # Plain assignment so set -e stops the script if tokens_used fails
    used=$(tokens_used "$err")
    if [ "$used" -ge $((CTX - 8)) ]; then
      truncated="$truncated $num"
      label="page $num: TRUNCATED at the context limit"
    fi
    if ! grep -q '[^[:space:]]' "$page_txt"; then
      empty=$((empty + 1))
    fi
    if [ "$page_count" -gt 1 ] || [ -n "$truncated" ]; then
      printf '\n<!-- %s -->\n\n' "$label" >> "$tmp_md"
    fi
    cat "$page_txt" >> "$tmp_md"
  done
}

finish() {
  mv -n "$tmp_md" "$out_file"
  [ ! -e "$tmp_md" ] || die "could not move the result into place: $out_file"
  echo "=== OCR complete ==="
  echo "output: $out_file"
  echo "pages:  $page_count (empty: $empty)"
  echo "chars:  $(wc -m < "$out_file" | tr -d ' ')"
  echo "mode:   $mode"
  echo "time:   ${SECONDS}s"
  if [ -n "$range_note" ]; then
    echo "note:   $range_note"
  fi
  if [ -n "$truncated" ]; then
    echo "WARNING: cut off at the context limit on page(s):$truncated"
  fi
  if [ "$private" -eq 1 ]; then
    echo "note:   private source; kept out of the vault"
  fi
}

# --- Main ---
check_tools
resolve_source
resolve_dest
ensure_server
check_model
render_pages
ocr_pages
finish

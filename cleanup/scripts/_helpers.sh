#!/bin/bash
set -e
# Shared helpers for cleanup scripts.
# Source this file: source "$(dirname "$0")/_helpers.sh"
#
# Every deletion in every mode routes through safe_trash / safe_trash_contents,
# so this file is the single seam for dry-run, the operations log, the
# protection list, and the whitelist.
#
# Environment:
#   CLEANUP_DRY_RUN=1   record what would be trashed, never move anything
#   CLEANUP_MODE=name   tag for the operations log (each script sets its own)

TOTAL_FREED=0
TOTAL_FAILED=0
TOTAL_REPORTED=0
REPORTED_COUNT=0
TRASHED_COUNT=0
SKIPPED_COUNT=0
WHITELIST_FILE="$HOME/.claude/cleanup-whitelist.txt"
PROTECTED_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/references/protected_patterns.txt"
PREVIEW_FILE="$HOME/.claude/cleanup-preview.txt"
OPLOG="$HOME/.claude/cleanup-operations.log"
OPLOG_MAX_KB=5120

DRY_RUN="${CLEANUP_DRY_RUN:-0}"
CLEANUP_MODE="${CLEANUP_MODE:-cleanup}"
CURRENT_SECTION="Uncategorized"
LEDGER=""

# ---------------------------------------------------------------------------
# Session lifecycle
# ---------------------------------------------------------------------------

# Print a section header and remember it for the dry-run ledger.
section() {
  CURRENT_SECTION="$1"
  echo "--- $1 ---"
}

# Rotate the operations log once it passes OPLOG_MAX_KB, then open a session.
start_run() {
  mkdir -p "$(dirname "$OPLOG")"
  if [ -f "$OPLOG" ] && [ "$(du -k "$OPLOG" | awk '{print $1}')" -gt "$OPLOG_MAX_KB" ]; then
    mv -f "$OPLOG" "$OPLOG.old"
  fi
  local tag="started"
  [ "$DRY_RUN" = "1" ] && tag="started (dry-run)"
  echo "# ==== $CLEANUP_MODE $tag at $(date '+%Y-%m-%d %H:%M:%S') ====" >> "$OPLOG"
  if [ "$DRY_RUN" = "1" ]; then
    LEDGER=$(mktemp "${TMPDIR:-/tmp}/cleanup-ledger.XXXXXX")
    echo "[DRY RUN] Nothing will be moved. Preview: $PREVIEW_FILE"
    echo ""
  fi
}

# Close the session in the log and, on a dry run, render the preview file.
finish_run() {
  echo "# ==== $CLEANUP_MODE ended at $(date '+%Y-%m-%d %H:%M:%S'), $TRASHED_COUNT items, $(format_size "$TOTAL_FREED"), skipped $SKIPPED_COUNT, failed $TOTAL_FAILED ====" >> "$OPLOG"
  if [ "$DRY_RUN" = "1" ] && [ -n "$LEDGER" ]; then
    render_preview
    rm -f "$LEDGER"
  fi
}

# Ledger rows are: section \t size_kb \t kind \t path
# Rendered grouped by section, largest first, in the order sections ran.
render_preview() {
  {
    echo "# /cleanup $CLEANUP_MODE preview - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "#"
    echo "# Nothing below was moved. To protect a path on the real run, copy it"
    echo "# into $WHITELIST_FILE (one glob per line)."
    echo "# 'report only' lines are shown for review and are never trashed."
    echo ""
    local sec
    while IFS= read -r sec; do
      [ -z "$sec" ] && continue
      echo "=== $sec ==="
      awk -F'\t' -v s="$sec" '$1 == s && !seen[$4]++' "$LEDGER" \
        | sort -t$'\t' -k2,2nr \
        | while IFS=$'\t' read -r _ size kind path; do
            if [ "$kind" = "report" ]; then
              echo "$path  # $(format_size "$size"), report only"
            else
              echo "$path  # $(format_size "$size")"
            fi
          done
      echo ""
    done < <(awk -F'\t' '!seen[$1]++ {print $1}' "$LEDGER")
  } > "$PREVIEW_FILE"
  echo ""
  echo "Dry-run preview written to $PREVIEW_FILE"
}

# ---------------------------------------------------------------------------
# Operations log
# ---------------------------------------------------------------------------

# oplog STATUS path [detail]
# STATUS: TRASHED | WOULD_TRASH | SKIPPED | FAILED | REPORTED
oplog() {
  local status="$1" path="$2" detail="${3:-}"
  if [ -n "$detail" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$CLEANUP_MODE] $status $path ($detail)" >> "$OPLOG"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$CLEANUP_MODE] $status $path" >> "$OPLOG"
  fi
}

# ---------------------------------------------------------------------------
# Protection and whitelist
# ---------------------------------------------------------------------------

# Patterns from references/protected_patterns.txt, matched against the full
# path with shell globbing. Loaded once; a missing file protects nothing.
_PROTECTED_PATTERNS=""
_load_protected() {
  [ -n "$_PROTECTED_PATTERNS" ] && return 0
  [ -f "$PROTECTED_FILE" ] || { _PROTECTED_PATTERNS=" "; return 0; }
  _PROTECTED_PATTERNS=$(grep -v '^[[:space:]]*#' "$PROTECTED_FILE" | grep -v '^[[:space:]]*$' || true)
  [ -z "$_PROTECTED_PATTERNS" ] && _PROTECTED_PATTERNS=" "
}

# True if the path matches any protected pattern. Protection is a hard stop
# that the whitelist cannot override and that dry-run reports as SKIPPED.
is_protected() {
  local path="$1"
  _load_protected
  local pattern expanded
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    expanded="${pattern/#\~/$HOME}"
    # shellcheck disable=SC2254
    case "$path" in
      $expanded) return 0 ;;
    esac
  done <<< "$_PROTECTED_PATTERNS"
  return 1
}

# Check if a path matches any whitelist pattern.
# Returns 0 (true) if whitelisted, 1 (false) if not.
# A path is whitelisted when it matches a pattern, when it is an ancestor of a
# whitelisted path (trashing the parent would take the protected child with
# it), or when it sits below a non-glob whitelisted directory.
is_whitelisted() {
  local path="${1%/}"
  [ ! -f "$WHITELIST_FILE" ] && return 1
  local pattern expanded literal
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    [[ "$pattern" == \#* ]] && continue
    expanded="${pattern/#\~/$HOME}"
    expanded="${expanded%/}"
    # shellcheck disable=SC2254
    case "$path" in
      $expanded) return 0 ;;
    esac
    # Ancestor of a whitelisted path (strip glob tail before comparing).
    literal="${expanded%%[\*\?\[]*}"
    literal="${literal%/}"
    [ -n "$literal" ] && [[ "$literal" == "$path"/* ]] && return 0
    # Descendant of a literal (non-glob) whitelisted directory.
    case "$expanded" in
      *[\*\?\[]*) ;;
      *) [[ "$path" == "$expanded"/* ]] && return 0 ;;
    esac
  done < "$WHITELIST_FILE"
  return 1
}

# ---------------------------------------------------------------------------
# Sizing with a timeout
# ---------------------------------------------------------------------------

# run_with_timeout SECS cmd args...  — exit 124 on timeout. macOS ships no
# timeout(1); perl's alarm is always available.
run_with_timeout() {
  local secs="$1"; shift
  perl -e '
    my $s = shift;
    my $pid = fork;
    if (!defined $pid) { exit 125 }
    if ($pid == 0) { exec @ARGV or exit 127 }
    $SIG{ALRM} = sub { kill "TERM", $pid; waitpid $pid, 0; exit 124 };
    alarm $s;
    waitpid $pid, 0;
    exit($? >> 8);
  ' "$secs" "$@"
}

# Returns size in KB for a path, 0 if missing, -1 if du timed out. A cloud
# placeholder folder can hang du indefinitely; an unknown size must never
# stall the run.
SIZE_TIMEOUT_SECS="${CLEANUP_SIZE_TIMEOUT:-10}"
safe_size() {
  [ -e "$1" ] || { echo 0; return 0; }
  local result rc=0
  result=$(run_with_timeout "$SIZE_TIMEOUT_SECS" du -sk "$1" 2>/dev/null | awk '{print $1}'; exit "${PIPESTATUS[0]}") || rc=$?
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 142 ]; then
    echo -1
  else
    echo "${result:-0}"
  fi
}

# Add a size to a running total, ignoring unknown (-1) sizes.
_add_size() {
  # $1 = variable name, $2 = size
  [ "$2" -ge 0 ] 2>/dev/null || return 0
  eval "$1=\$(( $1 + $2 ))"
}

# Format KB as human-readable. -1 means du timed out.
format_size() {
  local kb=$1
  if [ "$kb" -lt 0 ] 2>/dev/null; then
    echo "size unknown"
  elif [ "$kb" -ge 1048576 ]; then
    echo "$((kb / 1048576))GB"
  elif [ "$kb" -ge 1024 ]; then
    echo "$((kb / 1024))MB"
  else
    echo "${kb}KB"
  fi
}

# ---------------------------------------------------------------------------
# Process detection
# ---------------------------------------------------------------------------

# Tri-state: 0 running, 1 conclusively idle, 2 unknown (pgrep missing or
# errored). Callers must treat 2 as "do not delete" — an unknown state was
# previously indistinguishable from idle and deleted live caches.
is_app_running() {
  command -v pgrep >/dev/null 2>&1 || return 2
  local rc=0
  pgrep -xiq "$1" 2>/dev/null || rc=$?
  case "$rc" in
    0) return 0 ;;
    1) return 1 ;;
    *) return 2 ;;
  esac
}

# True only when the app is conclusively not running.
app_is_idle() {
  local rc=0
  is_app_running "$1" || rc=$?
  [ "$rc" -eq 1 ]
}

# Process table, loaded once per run. Excludes this shell, its ancestors
# (a wrapper like `bash -c '<script>'` carries the script text — and every ID
# it names — in its own argv) and this shell's direct children (a $(...)
# subshell is a fork with the same argv under a new pid).
_PROCESS_TABLE=""
_PROCESS_TABLE_APPS=""
_PROCESS_COMMS=""
_load_process_table() {
  [ -n "$_PROCESS_TABLE" ] && return 0
  local exclude="" pid=$$ ppid
  while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
    exclude="$exclude,$pid"
    ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ "$ppid" = "$pid" ] && break
    pid="$ppid"
  done
  _PROCESS_TABLE=$(ps -axo pid=,ppid=,comm=,args= 2>/dev/null \
    | awk -v ex="$exclude," -v me="$$" \
        'BEGIN{n=split(ex,a,",");for(i=1;i<=n;i++)if(a[i]!="")skip[a[i]]=1}
         !($1 in skip) && $2 != me' || true)
  [ -z "$_PROCESS_TABLE" ] && _PROCESS_TABLE=" "
  # Bare app names are substring-matched, and Apple's always-resident
  # PrivateFrameworks services (CursorUIViewService, ...) would pin unrelated
  # app caches forever. Bundle IDs keep the full table so Apple daemons like
  # mediaanalysisd are still seen.
  _PROCESS_TABLE_APPS=$(echo "$_PROCESS_TABLE" | grep -v '/System/Library/PrivateFrameworks/' || true)
  [ -z "$_PROCESS_TABLE_APPS" ] && _PROCESS_TABLE_APPS=" "
}

# cache_owner_running <bundle-id-or-dirname>
# Returns 0 when a process plausibly owns this cache, 1 when none does, 2 when
# the process table could not be read. A reverse-DNS id (com.foo.Bar) is
# considered running when the id itself appears in a command line, or when its
# leaf ("Bar", >=4 chars) and one distinctive vendor token ("foo") both appear
# on the same line. Names without dots are matched as substrings.
cache_owner_running() {
  local owner="$1"
  _load_process_table
  [ "$_PROCESS_TABLE" = " " ] && return 2
  case "$owner" in
    *.*) echo "$_PROCESS_TABLE" | grep -qiF -- "$owner" && return 0 ;;
    *)   echo "$_PROCESS_TABLE_APPS" | grep -qiF -- "$owner" && return 0; return 1 ;;
  esac
  # Walk back past generic leaves (com.apple.Foo-Settings.extension -> Foo-Settings):
  # "extension" + "apple" would match half the process table.
  local leaf="" rest="$owner"
  while [ -n "$rest" ]; do
    leaf="${rest##*.}"
    case "$rest" in *.*) rest="${rest%.*}" ;; *) rest="" ;; esac
    case "$(echo "$leaf" | tr '[:upper:]' '[:lower:]')" in
      extension|extensions|plugin|plugins|intents|helper|service|agent|daemon|widget|xpc|app|ui|mac|macos|desktop|client) continue ;;
    esac
    break
  done
  [ "${#leaf}" -lt 4 ] && return 1
  # Exact match on an executable's basename: com.apple.mediaanalysisd owns
  # /System/.../mediaanalysisd even though "apple" is nowhere in that path.
  [ -z "$_PROCESS_COMMS" ] && _PROCESS_COMMS=$(echo "$_PROCESS_TABLE" | awk '{n=split($4,p,"/"); print tolower(p[n])}' | sort -u)
  echo "$_PROCESS_COMMS" | grep -qxF -- "$(echo "$leaf" | tr '[:upper:]' '[:lower:]')" && return 0
  local token
  for token in $(echo "$owner" | tr '.' ' '); do
    [ "$token" = "$leaf" ] && continue
    case "$token" in
      com|org|net|io|co|app|apps|group|helper|agent|daemon|service) continue ;;
    esac
    [ "${#token}" -lt 3 ] && continue
    echo "$_PROCESS_TABLE" | grep -iF -- "$leaf" | grep -qiF -- "$token" && return 0
  done
  return 1
}

# True only when no process plausibly owns the cache.
cache_owner_idle() {
  local rc=0
  cache_owner_running "$1" || rc=$?
  [ "$rc" -eq 1 ]
}

# True if the path was modified within the last N days. A live app rewrites its
# support files constantly, so this catches false-positive orphans regardless of
# whether bundle-ID matching got the name right.
is_recently_modified() {
  local path="$1"
  local days="${2:-30}"
  [ -e "$path" ] || return 1
  find "$path" -maxdepth 0 -newermt "$days days ago" -print -quit 2>/dev/null | grep -q .
}

# ---------------------------------------------------------------------------
# Trash operations
# ---------------------------------------------------------------------------

# skip_path PATH REASON — record a guarded-out path and say so.
skip_path() {
  note_skip "$1" "$2"
  echo "  Skipped ($2): $1"
}

# note_skip PATH REASON — record a guarded-out path quietly (caller prints).
note_skip() {
  SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
  oplog SKIPPED "$1" "$2"
}

# Report a candidate for removal without deleting it. Used by orphan detection,
# where bundle-ID matching produces false positives for CLI tools, group
# containers, and system frameworks that own no .app bundle.
report_candidate() {
  local path="$1"
  local note="${2:-}"
  local size
  size=$(safe_size "$path")
  _add_size TOTAL_REPORTED "$size"
  REPORTED_COUNT=$((REPORTED_COUNT + 1))
  oplog REPORTED "$path" "$(format_size "$size")${note:+, $note}"
  [ -n "$LEDGER" ] && printf '%s\t%s\t%s\t%s\n' "$CURRENT_SECTION" "$size" report "$path" >> "$LEDGER"
  if [ -n "$note" ]; then
    echo "  $path ($(format_size "$size")) — $note"
  else
    echo "  $path ($(format_size "$size"))"
  fi
}

# Move path to Trash instead of rm -rf. Appends timestamp to avoid collisions.
# Guards, in order: protection list, whitelist. Under dry-run the guards still
# run and the outcome is recorded instead of executed.
safe_trash() {
  local path="$1"
  [ -e "$path" ] || return 0
  if is_protected "$path"; then skip_path "$path" protected; return 0; fi
  if is_whitelisted "$path"; then skip_path "$path" whitelisted; return 0; fi
  local size
  size=$(safe_size "$path")
  if [ "$DRY_RUN" = "1" ]; then
    _add_size TOTAL_FREED "$size"
    TRASHED_COUNT=$((TRASHED_COUNT + 1))
    oplog WOULD_TRASH "$path" "$(format_size "$size")"
    printf '%s\t%s\t%s\t%s\n' "$CURRENT_SECTION" "$size" trash "$path" >> "$LEDGER"
    echo "  Would trash: $path ($(format_size "$size"))"
    return 0
  fi
  local basename dest
  basename=$(basename "$path")
  dest="$HOME/.Trash/${basename}.$(date +%s%N 2>/dev/null || date +%s)"
  if mv -n "$path" "$dest" 2>/dev/null; then
    _add_size TOTAL_FREED "$size"
    TRASHED_COUNT=$((TRASHED_COUNT + 1))
    oplog TRASHED "$path -> $dest" "$(format_size "$size")"
    echo "  Trashed: $path ($(format_size "$size"))"
  else
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
    oplog FAILED "$path" "permission denied or locked"
    echo "  FAILED to trash: $path (permission denied or locked)" >&2
  fi
}

# Move contents of a directory to Trash (keeps the directory itself).
safe_trash_contents() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  if is_protected "$dir"; then skip_path "$dir" protected; return 0; fi
  if is_whitelisted "$dir"; then skip_path "$dir" whitelisted; return 0; fi
  local count=0 freed=0 failed=0 skipped=0 unknown=0
  local item bn item_size dest
  for item in "$dir"/* "$dir"/.*; do
    [ -e "$item" ] || continue
    bn=$(basename "$item")
    case "$bn" in
      .|..) continue ;;
    esac
    if is_protected "$item"; then
      skipped=$((skipped + 1)); SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      oplog SKIPPED "$item" protected
      continue
    fi
    if is_whitelisted "$item"; then
      skipped=$((skipped + 1)); SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      oplog SKIPPED "$item" whitelisted
      continue
    fi
    item_size=$(safe_size "$item")
    [ "$item_size" -lt 0 ] && unknown=$((unknown + 1))
    if [ "$DRY_RUN" = "1" ]; then
      count=$((count + 1))
      [ "$item_size" -ge 0 ] && freed=$((freed + item_size))
      oplog WOULD_TRASH "$item" "$(format_size "$item_size")"
      printf '%s\t%s\t%s\t%s\n' "$CURRENT_SECTION" "$item_size" trash "$item" >> "$LEDGER"
      continue
    fi
    dest="$HOME/.Trash/${bn}.$(date +%s%N 2>/dev/null || date +%s)"
    if mv -n "$item" "$dest" 2>/dev/null; then
      count=$((count + 1))
      [ "$item_size" -ge 0 ] && freed=$((freed + item_size))
      oplog TRASHED "$item -> $dest" "$(format_size "$item_size")"
    else
      failed=$((failed + 1))
      oplog FAILED "$item" "permission denied or locked"
    fi
  done
  local verb="Trashed"
  [ "$DRY_RUN" = "1" ] && verb="Would trash"
  if [ "$count" -gt 0 ]; then
    TOTAL_FREED=$((TOTAL_FREED + freed))
    TRASHED_COUNT=$((TRASHED_COUNT + count))
    if [ "$unknown" -gt 0 ]; then
      echo "  $verb $count items from $dir ($(format_size $freed) + $unknown of unknown size)"
    else
      echo "  $verb $count items from $dir ($(format_size $freed))"
    fi
  fi
  [ "$skipped" -gt 0 ] && echo "  Skipped $skipped protected/whitelisted item(s) in $dir"
  if [ "$failed" -gt 0 ]; then
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
    echo "  FAILED to trash $failed item(s) in $dir (permission denied or locked)" >&2
  fi
  return 0
}

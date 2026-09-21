#!/bin/bash
set -e

# Run all cleanup modes in sequence: session, system, forensic, purge

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================"
echo "  Full Cleanup: All Modes"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
[ "${CLEANUP_DRY_RUN:-0}" = "1" ] && echo "  DRY RUN — nothing will be moved"
echo "========================================"
echo ""
# CLEANUP_DRY_RUN is inherited by every mode script. Each mode overwrites the
# shared preview file, so keep a copy per mode for the combined report.
PREVIEW="$HOME/.claude/cleanup-preview.txt"
keep_preview() {
  [ "${CLEANUP_DRY_RUN:-0}" = "1" ] && [ -f "$PREVIEW" ] && cp "$PREVIEW" "${PREVIEW%.txt}-$1.txt"
  return 0
}

STATUS_SESSION="ok"
STATUS_SYSTEM="ok"
STATUS_FORENSIC="ok"
STATUS_PURGE="ok"

echo ">>> Running Session Cleanup..."
echo ""
bash "$SCRIPT_DIR/cleanup_session.sh" && keep_preview session || { STATUS_SESSION="FAILED"; echo "  [!] Session cleanup exited with errors — continuing." >&2; }
echo ""
echo ""

echo ">>> Running System Cache Cleanup..."
echo ""
bash "$SCRIPT_DIR/cleanup_system.sh" && keep_preview system || { STATUS_SYSTEM="FAILED"; echo "  [!] System cleanup exited with errors — continuing." >&2; }
echo ""
echo ""

echo ">>> Running Forensic Trace Cleanup..."
echo ""
bash "$SCRIPT_DIR/cleanup_forensic.sh" && keep_preview forensic || { STATUS_FORENSIC="FAILED"; echo "  [!] Forensic cleanup exited with errors — continuing." >&2; }
echo ""
echo ""

echo ">>> Running Project Artifact Purge..."
echo ""
bash "$SCRIPT_DIR/cleanup_purge.sh" && keep_preview purge || { STATUS_PURGE="FAILED"; echo "  [!] Purge exited with errors — continuing." >&2; }
echo ""
echo ""

echo "========================================"
echo "  Full Cleanup Complete"
echo "  Session:  $STATUS_SESSION"
echo "  System:   $STATUS_SYSTEM"
echo "  Forensic: $STATUS_FORENSIC"
echo "  Purge:    $STATUS_PURGE"
if [ "${CLEANUP_DRY_RUN:-0}" = "1" ]; then
  echo "  Previews: ${PREVIEW%.txt}-{session,system,forensic,purge}.txt"
fi
echo "========================================"

# Exit non-zero if any mode failed
if [ "$STATUS_SESSION" != "ok" ] || [ "$STATUS_SYSTEM" != "ok" ] || \
   [ "$STATUS_FORENSIC" != "ok" ] || [ "$STATUS_PURGE" != "ok" ]; then
  exit 1
fi

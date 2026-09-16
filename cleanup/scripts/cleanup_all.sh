#!/bin/bash
set -e

# Run all cleanup modes in sequence: session, system, forensic, purge

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================"
echo "  Full Cleanup: All Modes"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

STATUS_SESSION="ok"
STATUS_SYSTEM="ok"
STATUS_FORENSIC="ok"
STATUS_PURGE="ok"

echo ">>> Running Session Cleanup..."
echo ""
bash "$SCRIPT_DIR/cleanup_session.sh" || { STATUS_SESSION="FAILED"; echo "  [!] Session cleanup exited with errors — continuing." >&2; }
echo ""
echo ""

echo ">>> Running System Cache Cleanup..."
echo ""
bash "$SCRIPT_DIR/cleanup_system.sh" || { STATUS_SYSTEM="FAILED"; echo "  [!] System cleanup exited with errors — continuing." >&2; }
echo ""
echo ""

echo ">>> Running Forensic Trace Cleanup..."
echo ""
bash "$SCRIPT_DIR/cleanup_forensic.sh" || { STATUS_FORENSIC="FAILED"; echo "  [!] Forensic cleanup exited with errors — continuing." >&2; }
echo ""
echo ""

echo ">>> Running Project Artifact Purge..."
echo ""
bash "$SCRIPT_DIR/cleanup_purge.sh" || { STATUS_PURGE="FAILED"; echo "  [!] Purge exited with errors — continuing." >&2; }
echo ""
echo ""

echo "========================================"
echo "  Full Cleanup Complete"
echo "  Session:  $STATUS_SESSION"
echo "  System:   $STATUS_SYSTEM"
echo "  Forensic: $STATUS_FORENSIC"
echo "  Purge:    $STATUS_PURGE"
echo "========================================"

# Exit non-zero if any mode failed
if [ "$STATUS_SESSION" != "ok" ] || [ "$STATUS_SYSTEM" != "ok" ] || \
   [ "$STATUS_FORENSIC" != "ok" ] || [ "$STATUS_PURGE" != "ok" ]; then
  exit 1
fi

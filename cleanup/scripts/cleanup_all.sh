#!/bin/bash
set -e

# Run all cleanup modes in sequence: session, system, forensic

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================"
echo "  Full Cleanup: All Modes"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

echo ">>> Running Session Cleanup..."
echo ""
"$SCRIPT_DIR/cleanup_session.sh"
echo ""
echo ""

echo ">>> Running System Cache Cleanup..."
echo ""
"$SCRIPT_DIR/cleanup_system.sh"
echo ""
echo ""

echo ">>> Running Forensic Trace Cleanup..."
echo ""
"$SCRIPT_DIR/cleanup_forensic.sh"
echo ""
echo ""

echo "========================================"
echo "  Full Cleanup Complete"
echo "========================================"

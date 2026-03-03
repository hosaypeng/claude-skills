#!/bin/bash
set -e

echo "=== Health Check ==="

PENG_AI_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/Code/peng-ai"

if [ ! -d "$PENG_AI_DIR" ]; then
  echo "Error: peng-ai directory not found at $PENG_AI_DIR" >&2
  exit 1
fi

if [ ! -d "$PENG_AI_DIR/.venv" ]; then
  echo "Error: Python venv not found at $PENG_AI_DIR/.venv" >&2
  echo "Fix: cd $PENG_AI_DIR && python3 -m venv .venv && pip install -r requirements.txt" >&2
  exit 1
fi

cd "$PENG_AI_DIR"
source .venv/bin/activate

# Default to --dry-run (no Slack alerts). Pass --alert to send real alerts.
if [[ "$1" == "--alert" ]]; then
  echo "Running health check with LIVE Slack alerts..."
  python3 scripts/health_check.py
else
  echo "Running health check in dry-run mode (no Slack alerts)..."
  python3 scripts/health_check.py --dry-run
fi

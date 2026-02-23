#!/bin/bash
set -e

echo "=== Kill and Relaunch Sync ==="

if ! pgrep -x "Sync" > /dev/null 2>&1; then
  echo "Sync is not running. Launching..."
  open -a Sync --background
  echo "Sync launched."
  exit 0
fi

killall Sync 2>/dev/null
echo "Sync killed. Waiting 2 seconds..."
sleep 2
open -a Sync --background
echo "Sync relaunched in background."

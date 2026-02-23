#!/bin/bash
set -e

echo "=== Infostealer Detection: Persistence Mechanism Audit ==="

echo "=== User LaunchAgents ==="
ls -la ~/Library/LaunchAgents/ 2>/dev/null || echo "None"

echo "=== System LaunchAgents ==="
ls -la /Library/LaunchAgents/ 2>/dev/null || echo "None"

echo "=== System LaunchDaemons ==="
ls -la /Library/LaunchDaemons/ 2>/dev/null || echo "None"

echo "=== Recently Modified (30 days) ==="
find ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons -type f -mtime -30 2>/dev/null || echo "None"

#!/bin/bash
set -e

echo "=== Background Process Audit ==="

# List launch agents
echo "User launch agents:"
ls -1 ~/Library/LaunchAgents/*.plist 2>/dev/null | wc -l

echo ""
echo "Non-Apple services:"
launchctl list | grep -v "com.apple" | head -15

# Check for high-startup-impact apps
echo ""
echo "High-impact background processes (>0.5% CPU or >1% MEM):"
ps aux | awk '$3 > 0.5 || $4 > 1.0 {print $11, $3, $4}' | grep -v "Claude\|kernel_task\|WindowServer" | head -10 || echo "None found"

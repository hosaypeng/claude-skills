#!/bin/bash
set -e

echo "=== Suspicious Activity & Threats ==="

echo "--- Recent Crashes ---"
ls -lt ~/Library/Logs/DiagnosticReports/*.crash 2>/dev/null | head -5 | awk '{print $9, $6, $7, $8}' || echo "No recent crashes"

echo "--- Kernel Panics ---"
ls -lt /Library/Logs/DiagnosticReports/Kernel*.panic 2>/dev/null | head -3 || echo "No kernel panics"

echo "--- Suspicious Root Processes ---"
ps aux | awk '$1 == "root" && $3 > 1.0 {print $11}' | grep -v "kernel_task\|WindowServer\|launchd\|coreaudiod" | head -10 || echo "None"

echo "--- Hidden Files in Exploit Locations ---"
echo "In /tmp:"
find /tmp -name ".*" -type f 2>/dev/null | head -10 || echo "None"
echo "In ~/.ssh:"
find ~/.ssh -name ".*" -type f 2>/dev/null | head -5 || echo "None"

echo "--- Login Items ---"
osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null || echo "Could not retrieve login items"

echo "--- Third-Party Kernel Extensions ---"
kextstat 2>/dev/null | grep -v "com.apple" | head -10 || echo "None or kextstat unavailable"

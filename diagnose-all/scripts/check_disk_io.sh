#!/bin/bash
set -e

echo "=== Disk I/O Performance ==="

# Check disk usage
echo "Disk usage:"
df -h / | tail -1

# Get I/O stats
echo ""
echo "I/O stats:"
iostat -d -c 2 disk0 | tail -1

# Check if any process doing heavy I/O
echo ""
echo "Processes in disk wait state:"
ps aux | awk '{if ($8 ~ /D/) print $0}' | head -10 || echo "No processes in disk wait"

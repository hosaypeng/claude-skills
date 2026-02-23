#!/bin/bash
set -e

echo "=== Backup & Update Status ==="

# Time Machine status
echo "Time Machine latest backup:"
tmutil latestbackup 2>/dev/null || echo "Time Machine not configured"

echo ""
echo "Time Machine status:"
tmutil status 2>/dev/null | grep -E "Running|BackupPhase" || echo "Not backing up"

# Last backup date
echo ""
echo "Last backup date:"
latest=$(tmutil latestbackup 2>/dev/null) && ls -ld "$latest" 2>/dev/null | awk '{print $6, $7, $8}' || echo "N/A"

# Software updates available
echo ""
echo "Software updates:"
softwareupdate -l 2>/dev/null | grep -E "Title|recommended" || echo "No updates available"

# Check if FileVault is enabled
echo ""
echo "FileVault status:"
fdesetup status 2>/dev/null || echo "FileVault status unavailable"

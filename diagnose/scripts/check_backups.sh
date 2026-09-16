#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Backup Status (Time Machine) ==="

# Software updates are reported by check_updates.sh and FileVault by check_encryption.sh.
# Running softwareupdate -l here too meant two network round-trips to Apple for the same
# data, and it is the slowest single call in the suite.

echo "=== Configured Destinations ==="
dest=$(tmutil destinationinfo 2>&1)
if echo "$dest" | grep -q "No destinations configured"; then
  echo "[HIGH] Time Machine has no destination configured - no backups are being taken"
else
  echo "$dest"
fi

echo "=== Latest Backup ==="
# tmutil latestbackup exits non-zero and prints nothing when there are no snapshots,
# so an unguarded call leaves a blank line that reads as "fine" in the report.
latest=$(tmutil latestbackup 2>/dev/null)
if [ -n "$latest" ]; then
  echo "$latest"
  echo "Backup date: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$latest" 2>/dev/null || echo unknown)"
else
  echo "[HIGH] No completed Time Machine backup found"
fi

echo "=== Local Snapshots ==="
snaps=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c "com.apple.TimeMachine")
if [ "${snaps:-0}" -gt 0 ]; then
  echo "Local APFS snapshots: $snaps (most recent: $(tmutil listlocalsnapshots / 2>/dev/null | tail -1))"
else
  echo "No local APFS snapshots"
fi

echo "=== Current Activity ==="
tmutil status 2>/dev/null | grep -E "Running|BackupPhase" || echo "Not currently backing up"

exit 0

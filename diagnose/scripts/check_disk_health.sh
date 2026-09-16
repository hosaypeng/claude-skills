#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Disk Health (SMART Status) ==="

# Get SMART status
echo "SMART status:"
diskutil info disk0 | grep -E "SMART Status|Solid State|Media Name"

# More detailed SMART data (requires admin)
echo ""
echo "SMART details:"
# smartctl ships with smartmontools, not macOS. Say so rather than failing silently.
if command -v smartctl >/dev/null 2>&1; then
  smartctl -a disk0 2>/dev/null | grep -E "Temperature|Power_On_Hours|Wear_Leveling|Reallocated|Pending_Sector|Available_Reservd_Space|Percentage Used" || echo "smartctl returned no detail (may need admin)"
else
  echo "smartctl not installed - run 'brew install smartmontools' for SMART detail"
fi

# Check disk errors in system log
echo ""
echo "Disk errors (last 24h):"
# Apple Silicon storage is NVMe (IONVMeFamily); IOAHCIBlockStorage is the Intel SATA path.
log show --predicate '(subsystem CONTAINS "IONVMe" OR subsystem == "com.apple.iokit.IOAHCIBlockStorage") AND eventMessage CONTAINS[c] "error"' --last 24h --style compact 2>/dev/null | grep -v "^Timestamp" | grep -c . || echo "Log check unavailable"

# Get disk temperature if available
echo ""
echo "Disk temperature:"
ioreg -r -c IOBlockStorageDriver | grep -E "Temperature|temperature" || echo "Temperature unavailable"

exit 0

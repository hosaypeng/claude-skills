#!/bin/bash
set -e

echo "=== Disk Health (SMART Status) ==="

# Get SMART status
echo "SMART status:"
diskutil info disk0 | grep -E "SMART Status|Solid State|Media Name"

# More detailed SMART data (requires admin)
echo ""
echo "SMART details:"
smartctl -a disk0 2>/dev/null | grep -E "Temperature|Power_On_Hours|Wear_Leveling|Reallocated|Pending_Sector|Available_Reservd_Space|Percentage Used" || echo "SMART details require admin access"

# Check disk errors in system log
echo ""
echo "Disk errors (last 24h):"
log show --predicate 'subsystem == "com.apple.iokit.IOAHCIBlockStorage"' --last 24h 2>/dev/null | grep -i error | wc -l || echo "Log check unavailable"

# Get disk temperature if available
echo ""
echo "Disk temperature:"
ioreg -r -c IOBlockStorageDriver | grep -E "Temperature|temperature" || echo "Temperature unavailable"

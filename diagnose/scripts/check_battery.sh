#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Battery Health ==="

# Get battery info from ioreg
echo "Raw battery data:"
ioreg -r -c AppleSmartBattery | grep -E "MaxCapacity|CurrentCapacity|CycleCount|DesignCapacity|Temperature|PermanentFailureStatus|CellVoltage|BatteryInstalled" || echo "Battery info unavailable" >&2

# Get system profiler battery data
echo ""
echo "System profiler battery data:"
system_profiler SPPowerDataType | grep -E "Condition|Cycle Count|Full Charge|Health" || echo "Power data unavailable" >&2

exit 0

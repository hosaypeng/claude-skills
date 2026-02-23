#!/bin/bash
set -e

echo "=== Battery Health ==="

# Get battery info from ioreg
echo "Raw battery data:"
ioreg -r -c AppleSmartBattery | grep -E "MaxCapacity|CurrentCapacity|CycleCount|DesignCapacity|Temperature|PermanentFailureStatus|CellVoltage|BatteryInstalled" || echo "Battery info unavailable" >&2

# Get system profiler battery data
echo ""
echo "System profiler battery data:"
system_profiler SPPowerDataType | grep -E "Condition|Cycle Count|Full Charge|Health" || echo "Power data unavailable" >&2

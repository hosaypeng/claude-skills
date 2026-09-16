#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Battery Health ==="

raw=$(ioreg -r -c AppleSmartBattery 2>/dev/null)
if [ -z "$raw" ]; then
  echo "Battery info unavailable (no battery, or ioreg failed)"
else
  # macOS 27 removed the top-level AppleRawMaxCapacity, Temperature and CellVoltage keys.
  # Capacity figures now sit inside one "BatteryData" dictionary; CycleCount stays top-level.
  bd=$(echo "$raw" | grep '"BatteryData"' | head -1)
  bd_key() { echo "$bd" | sed -n "s/.*\"$1\"=\([0-9]*\).*/\1/p"; }
  top_key() { echo "$raw" | sed -n "s/.*\"$1\" = \([0-9]*\).*/\1/p" | head -1; }

  full=$(bd_key FullChargeCapacity)
  nominal=$(bd_key NominalChargeCapacity)
  design=$(bd_key DesignCapacity)
  cycles=$(top_key CycleCount)
  design_cycles=$(top_key DesignCycleCount9C)

  echo "Capacity (mAh):"
  echo "  FullChargeCapacity:    ${full:-unavailable}"
  echo "  NominalChargeCapacity: ${nominal:-unavailable}"
  echo "  DesignCapacity:        ${design:-unavailable}"
  if [ -n "$full" ] && [ -n "$design" ] && [ "$design" -gt 0 ]; then
    echo "  Health (Full/Design):  $(( full * 100 / design ))%"
  fi
  echo "Cycles: ${cycles:-unavailable} of ${design_cycles:-unavailable} rated"

  echo ""
  echo "Other keys:"
  echo "$raw" | grep -E '^ *\| *"(CurrentCapacity|MaxCapacity|IsCharging|ExternalConnected|BatteryInstalled|PermanentFailureStatus|Temperature)" =' \
    || echo "  none"
fi

# Apple's own verdict. Condition: Normal / Service Recommended.
echo ""
echo "System profiler battery data:"
system_profiler SPPowerDataType 2>/dev/null | grep -E "Condition|Cycle Count|Maximum Capacity|Health" \
  || echo "Power data unavailable"

exit 0

#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Thermal Status ==="

# `pmset -g thermlog` is a continuous monitor that never returns - using it here hung
# /diagnose full and /diagnose hardware indefinitely. `-g therm` reports current state
# and exits.
echo "Thermal / performance warning levels:"
pmset -g therm 2>/dev/null || echo "Thermal state unavailable"

echo ""
echo "CPU thermal level:"
sysctl machdep.xcpm.cpu_thermal_level 2>/dev/null || echo "Thermal level: unavailable (Apple Silicon does not expose this)"

echo ""
echo "Thermal-related power assertions:"
pmset -g assertions 2>/dev/null | grep -iE "thermal|cpu" || echo "None reported"

exit 0

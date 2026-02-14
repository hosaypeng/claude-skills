#!/bin/bash
set -e

echo "=== Thermal Status ==="

# Check for thermal pressure (macOS)
echo "Thermal log:"
pmset -g thermlog 2>/dev/null || echo "Thermal monitoring not available"

# Check if CPU is throttling
echo ""
echo "CPU thermal level:"
sysctl machdep.xcpm.cpu_thermal_level 2>/dev/null || echo "Thermal level: unavailable"

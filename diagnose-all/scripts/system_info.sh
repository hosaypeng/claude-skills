#!/bin/bash
set -e

echo "=== System Info ==="

# Hardware specs
system_profiler SPHardwareDataType 2>/dev/null | grep -E "Chip|Total Number of Cores|Memory" || echo "Hardware info unavailable" >&2

# Load average
echo ""
echo "Load average:"
sysctl -n vm.loadavg

# Uptime
echo ""
echo "Uptime:"
uptime

# CPU count
echo ""
echo "CPU count:"
sysctl -n hw.ncpu

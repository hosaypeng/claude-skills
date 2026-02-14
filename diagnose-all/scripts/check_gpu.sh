#!/bin/bash
set -e

echo "=== GPU & Graphics Performance ==="

# Get GPU info and usage
echo "GPU info:"
system_profiler SPDisplaysDataType | grep -E "Chipset Model|VRAM|Resolution|Displays"

# Check GPU memory pressure (Metal)
echo ""
echo "GPU stats:"
ioreg -r -c "IOAccelerator" | grep -E "PerformanceStatistics" -A 20 | grep -E "Device Utilization|vramUsedBytes|vramFreeBytes" || echo "GPU stats unavailable"

# Top GPU-using processes
echo ""
echo "Top GPU-using processes (>5% CPU):"
ps aux | awk '{if ($3 > 5.0) print $11, $3}' | head -10 || echo "None"

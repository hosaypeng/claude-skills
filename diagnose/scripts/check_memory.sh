#!/bin/bash
set -e

echo "=== Memory Usage ==="

# Memory overview
top -l 1 -n 0 | grep -E "PhysMem|VM:"

# Swap usage
echo ""
echo "Swap usage:"
sysctl vm.swapusage

# Top memory consumers by app (aggregated)
echo ""
echo "Top memory consumers (MB):"
ps axo rss,comm | awk '{sum[$2]+=$1} END {for (p in sum) print sum[p]/1024, p}' | sort -rn | head -15

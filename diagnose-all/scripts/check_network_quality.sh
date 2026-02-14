#!/bin/bash
set -e

echo "=== Network Throughput & Quality ==="

# Get current network interface stats
echo "Interface stats:"
netstat -ib | grep -E "en0|en1" | head -2

# Check for packet errors/drops
echo ""
echo "Packet errors/drops:"
netstat -s | grep -E "packet loss|retransmit|out-of-order" | head -5 || echo "No packet issues found"

# WiFi signal strength and quality
echo ""
echo "WiFi signal:"
/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep -E "agrCtlRSSI|agrCtlNoise|lastTxRate|maxRate" || echo "WiFi info unavailable"

# Active network bandwidth (sample over 2 seconds)
echo ""
echo "Network bandwidth:"
nettop -P -L 1 -t wifi -t wired 2>/dev/null | head -5 || echo "nettop unavailable"

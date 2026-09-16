#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

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
# The airport binary was removed by Apple in macOS 14.4. SPAirPortDataType needs no sudo
# and carries the same fields; `sudo wdutil info` is the privileged alternative.
system_profiler SPAirPortDataType 2>/dev/null \
  | awk '/Current Network Information/{f=1} f&&/Other Local Wi-Fi/{exit} f' \
  | grep -E "PHY Mode|Channel|Security|Signal / Noise|Transmit Rate" \
  || echo "WiFi info unavailable (no Wi-Fi interface, or Wi-Fi is off)"

# Active network bandwidth (sample over 2 seconds)
echo ""
echo "Network bandwidth:"
nettop -P -L 1 -t wifi -t wired 2>/dev/null | head -5 || echo "nettop unavailable"

exit 0

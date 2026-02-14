#!/bin/bash
set -e

echo "=== Security Audit ==="

# Open ports (listening)
echo "Open ports (listening):"
lsof -iTCP -sTCP:LISTEN -P -n | awk 'NR>1 {print $1, $9}' | sort -u

# Firewall status
echo ""
echo "Firewall status:"
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "Firewall check unavailable"

# Check for unexpected listeners on common ports
echo ""
echo "Listeners on common ports:"
lsof -iTCP:80,443,22,3306,5432,6379,27017 -sTCP:LISTEN -P -n 2>/dev/null | tail -n +2 || echo "No listeners on common ports"

# VPN status
echo ""
echo "VPN status:"
scutil --nc list | grep Connected || echo "No active VPN"

# Recent crashes
echo ""
echo "Recent crashes:"
ls -lt ~/Library/Logs/DiagnosticReports/*.crash 2>/dev/null | head -5 | awk '{print $9}' || echo "No recent crashes"

# Kernel panics
echo ""
echo "Kernel panics:"
ls -lt /Library/Logs/DiagnosticReports/Kernel*.panic 2>/dev/null | head -3 | awk '{print $9}' || echo "No kernel panics"

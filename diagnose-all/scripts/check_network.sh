#!/bin/bash
set -e

echo "=== Network Activity ==="

# Get active connections count
echo "Active connections:"
netstat -an | grep ESTABLISHED | wc -l

# Top network-using processes
echo ""
echo "Top network-using processes:"
nettop -P -L 1 -t wifi -t wired 2>/dev/null | head -20 || lsof -i -n -P | awk '{print $1}' | sort | uniq -c | sort -rn | head -10

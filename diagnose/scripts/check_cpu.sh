#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== CPU Usage ==="

# Top 20 CPU consumers
ps aux -r | head -20

exit 0

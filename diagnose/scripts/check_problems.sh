#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Problem Detection ==="

# Zombie processes
echo "Zombie processes:"
ps axo pid,ppid,state,etime,comm | grep -E '^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+(Z|U)' || echo "No zombie processes"

# Long-running dev processes
echo ""
echo "Long-running dev processes:"
ps axo pid,etime,pcpu,pmem,comm | grep -E "claude|node|git|rg|bun|npm" | grep -v grep || echo "None found"

exit 0

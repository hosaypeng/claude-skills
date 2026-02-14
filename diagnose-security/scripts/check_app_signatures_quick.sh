#!/bin/bash
set -e

echo "=== Application Signature Summary (Quick Scan) ==="

for app in /Applications/*.app; do
    name=$(basename "$app")
    result=$(codesign -v "$app" 2>&1)
    if [ $? -eq 0 ]; then
        authority=$(codesign -dv "$app" 2>&1 | grep "Authority=" | head -1 | sed 's/Authority=//')
        echo "VALID: $name - $authority"
    else
        echo "INVALID: $name - UNSIGNED or INVALID: $result" >&2
    fi
done

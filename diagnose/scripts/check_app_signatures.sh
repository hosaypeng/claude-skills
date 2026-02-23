#!/bin/bash
set -e

echo "=== Application Integrity Check: All Desktop Apps ==="

echo "=== Scanning All Applications ==="
for app in /Applications/*.app /Applications/**/*.app; do
    if [ -d "$app" ]; then
        echo "Checking: $app"
        codesign -dv --verbose=2 "$app" 2>&1 | grep -E "Identifier=|Authority=|TeamIdentifier=|Signature=|Error:" || true
        echo "---"
    fi
done 2>/dev/null

#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Application Integrity Check: All Desktop Apps ==="

echo "=== Scanning All Applications ==="
while IFS= read -r app; do
    if [ -d "$app" ]; then
        echo "Checking: $app"
        codesign -dv --verbose=2 "$app" 2>&1 | grep -E "Identifier=|Authority=|TeamIdentifier=|Signature=|Error:" || true
        echo "---"
    fi
done < <(find /Applications -maxdepth 2 -name "*.app" -type d 2>/dev/null)

exit 0

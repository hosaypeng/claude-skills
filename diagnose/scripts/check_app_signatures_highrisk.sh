#!/bin/bash
set -e

echo "=== High-Risk Category Apps (Common Piracy Targets) ==="

for pattern in "Adobe" "Parallels" "CleanMyMac" "DaVinci" "Resolve" "Microsoft" "Office" "Final Draft" "Logic Pro" "Final Cut" "Sketch" "Affinity" "Sublime" "JetBrains" "VMware" "AutoCAD" "Maya" "Cinema 4D" "Ableton" "FL Studio" "Serum" "Native Instruments"; do
    for app in /Applications/*"$pattern"* /Applications/**/*"$pattern"*; do
        if [ -d "$app" ] 2>/dev/null; then
            echo "=== $app ==="
            codesign -dv --verbose=2 "$app" 2>&1 | grep -E "Identifier=|Authority=|TeamIdentifier=|Timestamp=" || true
        fi
    done 2>/dev/null
done

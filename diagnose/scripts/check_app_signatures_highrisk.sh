#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== High-Risk Category Apps (Common Piracy Targets) ==="

PATTERNS="Adobe|Parallels|CleanMyMac|DaVinci|Resolve|Microsoft|Office|Final Draft|Logic Pro|Final Cut|Sketch|Affinity|Sublime|JetBrains|VMware|AutoCAD|Maya|Cinema 4D|Ableton|FL Studio|Serum|Native Instruments"

# bash 3.2 has no globstar, so /Applications/**/* silently meant /Applications/*/*.
# find with -maxdepth 2 covers both levels explicitly.
while IFS= read -r app; do
    [ -d "$app" ] || continue
    echo "=== $app ==="
    codesign -dv --verbose=2 "$app" 2>&1 | grep -E "Identifier=|Authority=|TeamIdentifier=|Timestamp=" || true
done < <(find /Applications -maxdepth 2 -name "*.app" -type d 2>/dev/null | grep -Ei "$PATTERNS")

exit 0

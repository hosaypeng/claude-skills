#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Application Signature Summary (Quick Scan) ==="

# Top-level bundles only. Nested bundles are covered by check_app_signatures.sh.
for app in /Applications/*.app; do
    [ -d "$app" ] || continue
    name=$(basename "$app")
    if result=$(codesign -v "$app" 2>&1); then
        # Authority only appears at --verbose=2; plain -dv omits it entirely.
        authority=$(codesign -dv --verbose=2 "$app" 2>&1 | sed -n 's/^Authority=//p' | head -1)
        echo "VALID: $name - ${authority:-unknown authority}"
    else
        # Findings go to stdout alongside the passes; stderr would bury the half that matters.
        echo "[CRITICAL] INVALID: $name - $(echo "$result" | head -1 | sed "s|^$app: ||")"
    fi
done

exit 0

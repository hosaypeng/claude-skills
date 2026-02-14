#!/bin/bash
set -e

echo "=== Browser Security (Safari & Chrome) ==="

echo "--- Safari Privacy Settings ---"
echo -n "Fraudulent site warnings: "
defaults read com.apple.Safari WarnAboutFraudulentWebsites 2>/dev/null || echo "unknown"
echo -n "Do Not Track: "
defaults read com.apple.Safari SendDoNotTrackHTTPHeader 2>/dev/null || echo "unknown"

echo "--- Safari Extensions ---"
ls ~/Library/Safari/Extensions/ 2>/dev/null | head -10 || echo "None"

echo "--- Tracking Prevention ---"
echo -n "Private click measurement: "
defaults read com.apple.Safari WebKitPreferences.privateClickMeasurementEnabled 2>/dev/null || echo "unknown"

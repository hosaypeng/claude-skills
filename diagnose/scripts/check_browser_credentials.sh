#!/bin/bash
set -e

echo "=== Infostealer Detection: Browser Credential Store Audit ==="

echo "=== Browser Profile Locations ==="

echo "--- Chrome ---"
ls -la ~/Library/Application\ Support/Google/Chrome/Default/ 2>/dev/null | grep -E "Login Data|Cookies|Web Data" || echo "Not found"

echo "--- Firefox ---"
ls -la ~/Library/Application\ Support/Firefox/Profiles/ 2>/dev/null || echo "Not found"

echo "--- Safari ---"
ls -la ~/Library/Safari/ 2>/dev/null | grep -E "History|Downloads|Cookies" || echo "Not found"

echo "--- Brave ---"
ls -la ~/Library/Application\ Support/BraveSoftware/Brave-Browser/Default/ 2>/dev/null | grep -E "Login Data|Cookies" || echo "Not found"

echo "--- Arc ---"
ls -la ~/Library/Application\ Support/Arc/User\ Data/Default/ 2>/dev/null | grep -E "Login Data|Cookies" || echo "Not found"

echo "=== Recent Credential DB Access ==="
find ~/Library/Application\ Support/Google/Chrome -name "Login Data" -mtime -1 2>/dev/null || echo "None"
find ~/Library/Application\ Support/Firefox -name "logins.json" -mtime -1 2>/dev/null || echo "None"

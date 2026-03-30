#!/bin/bash
set -e

# sweep_browser_extensions.sh — Enumerate browser extensions across all major browsers

echo "=== Safari Extensions ==="
pluginkit -mDvp com.apple.Safari.web-extension 2>/dev/null | grep -E "^    " | head -20 || echo "  No Safari extensions found or pluginkit unavailable"

echo "=== Chrome Extensions ==="
chrome_dir="/Users/$USER/Library/Application Support/Google/Chrome"
if [ -d "$chrome_dir" ]; then
  find "$chrome_dir" -path "*/Extensions/*/manifest.json" -maxdepth 6 2>/dev/null | while read -r manifest; do
    name=$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d.get('name','UNKNOWN'))" "$manifest" 2>/dev/null || echo "PARSE_ERROR")
    echo "  $name"
  done | sort -u | head -30
else
  echo "  Chrome not installed"
fi

echo "=== Firefox Extensions ==="
ff_dir="/Users/$USER/Library/Application Support/Firefox/Profiles"
if [ -d "$ff_dir" ]; then
  find "$ff_dir" -name "extensions.json" -maxdepth 2 2>/dev/null | while read -r extfile; do
    python3 -c "
import json,sys
data=json.load(open(sys.argv[1]))
for a in data.get('addons',[]):
  if a.get('type')=='extension' and a.get('active'):
    print('  '+a.get('defaultLocale',{}).get('name',a.get('id','UNKNOWN')))
" "$extfile" 2>/dev/null || true
  done | head -30
else
  echo "  Firefox not installed"
fi

echo "=== Arc Extensions ==="
arc_dir="/Users/$USER/Library/Application Support/Arc/User Data"
if [ -d "$arc_dir" ]; then
  find "$arc_dir" -path "*/Extensions/*/manifest.json" -maxdepth 6 2>/dev/null | while read -r manifest; do
    name=$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d.get('name','UNKNOWN'))" "$manifest" 2>/dev/null || echo "PARSE_ERROR")
    echo "  $name"
  done | sort -u | head -30
else
  echo "  Arc not installed"
fi

echo "=== Brave Extensions ==="
brave_dir="/Users/$USER/Library/Application Support/BraveSoftware/Brave-Browser"
if [ -d "$brave_dir" ]; then
  find "$brave_dir" -path "*/Extensions/*/manifest.json" -maxdepth 6 2>/dev/null | while read -r manifest; do
    name=$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d.get('name','UNKNOWN'))" "$manifest" 2>/dev/null || echo "PARSE_ERROR")
    echo "  $name"
  done | sort -u | head -30
else
  echo "  Brave not installed"
fi

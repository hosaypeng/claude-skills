#!/bin/bash
# sweep_browser_extensions.sh — Enumerate browser extensions across installed browsers
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Safari Extensions ==="
exts=$(pluginkit -mDvp com.apple.Safari.web-extension 2>/dev/null | grep -E "^    " | head -20)
if [ -n "$exts" ]; then
  echo "$exts"
else
  echo "  None (or pluginkit unavailable)"
fi

TAB=$(printf '\t')

# Chromium-family browsers share the profile layout. Print id + name + version so an
# unfamiliar entry can be looked up in the Web Store, and store-installed vs sideloaded is
# visible from the id. Unpacked (sideloaded) extensions are the interesting ones.
list_chromium_extensions() {
  local label="$1" dir="$2" manifest id name version
  echo "=== $label Extensions ==="
  if [ ! -d "$dir" ]; then
    echo "  $label not installed"
    return 0
  fi
  list=$(find "$dir" -path "*/Extensions/*/manifest.json" -maxdepth 6 2>/dev/null | while IFS= read -r manifest; do
    id=$(basename "$(dirname "$(dirname "$manifest")")")
    name=$(python3 -c "$RESOLVE_NAME" "$manifest" 2>/dev/null || echo "PARSE_ERROR")
    version=$(basename "$(dirname "$manifest")")
    printf '%s\t%s\t%s\n' "$id" "$version" "$name"
  done | sort -t "$TAB" -k1,1 -k2,2Vr \
    | awk -F "$TAB" '{ if ($1 != last) printf "  %s  %s (%s)\n", $1, $3, $2; last = $1 }' | head -40)
  if [ -n "$list" ]; then echo "$list"; else echo "  None installed"; fi
  return 0
}

# Manifest names are often "__MSG_appName__", resolved from _locales/<default_locale>/messages.json.
RESOLVE_NAME='
import json, os, sys
m = sys.argv[1]
d = json.load(open(m))
name = d.get("name", "UNKNOWN")
if name.startswith("__MSG_"):
  key = name[6:-2]
  loc = d.get("default_locale", "en")
  for cand in (loc, "en", "en_US"):
    f = os.path.join(os.path.dirname(m), "_locales", cand, "messages.json")
    if os.path.exists(f):
      msgs = json.load(open(f))
      hit = msgs.get(key) or {k.lower(): v for k, v in msgs.items()}.get(key.lower())
      if hit:
        name = hit.get("message", name)
        break
print(name)
'


list_chromium_extensions "Chrome"  "$HOME/Library/Application Support/Google/Chrome"
list_chromium_extensions "Brave"   "$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
list_chromium_extensions "Helium"  "$HOME/Library/Application Support/net.imput.helium"
list_chromium_extensions "Arc"     "$HOME/Library/Application Support/Arc/User Data"
list_chromium_extensions "Edge"    "$HOME/Library/Application Support/Microsoft Edge"

echo "=== Firefox Extensions ==="
ff_dir="$HOME/Library/Application Support/Firefox/Profiles"
if [ -d "$ff_dir" ]; then
  ff_list=$(find "$ff_dir" -name "extensions.json" -maxdepth 2 2>/dev/null | while IFS= read -r extfile; do
    python3 -c "
import json,sys
data=json.load(open(sys.argv[1]))
for a in data.get('addons',[]):
  if a.get('type')=='extension' and a.get('active'):
    print('  '+a.get('id','?')+'  '+a.get('defaultLocale',{}).get('name',a.get('id','UNKNOWN')))
" "$extfile" 2>/dev/null
  done | head -30)
  if [ -n "$ff_list" ]; then echo "$ff_list"; else echo "  None installed"; fi
else
  echo "  Firefox not installed"
fi

exit 0

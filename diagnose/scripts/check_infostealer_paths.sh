#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Infostealer Detection: Temp & Hidden Path Audit ==="

# An unsigned Mach-O binary staged in a world-writable temp directory is a real
# behavioural indicator, unlike a filename-pattern guess.
echo "=== Mach-O Binaries in Temp Directories ==="
found=0
while IFS= read -r f; do
  if file -b "$f" 2>/dev/null | grep -q "Mach-O"; then
    if codesign -v "$f" >/dev/null 2>&1; then
      echo "  [MEDIUM] Signed Mach-O in temp: $f"
    else
      echo "  [CRITICAL] UNSIGNED Mach-O in temp: $f"
    fi
    found=1
  fi
done < <(find -H /tmp /var/tmp -maxdepth 3 -type f 2>/dev/null)   # -H: /tmp is a symlink
[ "$found" -eq 0 ] && echo "  None found (good)"

echo "=== Unsigned Loadable Code in /private/var/folders ==="
found=0
while IFS= read -r f; do
  codesign -v "$f" >/dev/null 2>&1 || { echo "  [MEDIUM] Unsigned: $f"; found=1; }
done < <(find /private/var/folders -maxdepth 5 -type f \
  \( -name "*.dylib" -o -name "*.so" -o -name "*.bundle" \) 2>/dev/null | head -20)
[ "$found" -eq 0 ] && echo "  None found or not readable"

echo "=== Executable Files in /tmp ==="
execs=$(find -H /tmp -maxdepth 3 -type f -perm +111 2>/dev/null | head -20)
if [ -n "$execs" ]; then
  echo "$execs" | while IFS= read -r f; do
    echo "  $f ($(file -b "$f" 2>/dev/null | cut -c1-50))"
  done
else
  echo "  None"
fi

echo "=== Hidden Entries in Application Support ==="
# The previous glob here expanded to ~/. and ~/.. and dumped the entire home directory.
hidden=$(find "$HOME/Library/Application Support" -maxdepth 1 -name ".*" 2>/dev/null | grep -v '/\.DS_Store$')
if [ -n "$hidden" ]; then
  echo "$hidden" | sed 's/^/  /'
else
  echo "  None"
fi

echo "=== Hidden Files in Shared Directories ==="
# .DS_Store/.localized and friends are standard macOS furniture; flagging them buries
# the one entry that would actually matter.
BENIGN='/\.(DS_Store|localized|betamigrated|com\.apple\.timemachine)'
shared=$(find /Users/Shared -maxdepth 2 -name ".*" -type f 2>/dev/null | grep -vE "$BENIGN" | head -10)
if [ -n "$shared" ]; then
  echo "$shared" | sed 's/^/  [MEDIUM] /'
else
  echo "  None (excluding standard macOS files)"
fi

exit 0

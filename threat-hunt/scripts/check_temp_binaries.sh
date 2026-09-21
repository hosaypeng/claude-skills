#!/bin/bash
# check_temp_binaries.sh — Detect Mach-O binaries and loadable code staged in temp directories
# Probe script: try each check, print what works, never abort on a failed sub-check.

# An unsigned Mach-O staged in a world-writable temp directory is a real behavioural
# indicator, unlike a filename-pattern guess.
# /tmp and /var/tmp are symlinks into /private; BSD find does not descend a command-line
# symlink, so without -H these sections were always empty.
echo "=== Mach-O Binaries in /tmp and /var/tmp ==="
found=0
while IFS= read -r f; do
  file -b "$f" 2>/dev/null | grep -q "Mach-O" || continue
  found=1
  if codesign -v "$f" >/dev/null 2>&1; then
    echo "  [MEDIUM] Signed Mach-O in temp: $f"
  else
    echo "  [CRITICAL] UNSIGNED Mach-O in temp: $f"
  fi
done < <(find -H /tmp /var/tmp -maxdepth 3 -type f 2>/dev/null)
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

exit 0

#!/bin/bash
set -e

# check_temp_binaries.sh — Detect Mach-O binaries in temp directories

echo "=== Mach-O Binaries in /tmp ==="
macho_hits=$(find /tmp -type f -maxdepth 3 2>/dev/null | while read -r f; do
  if file "$f" 2>/dev/null | grep -q "Mach-O"; then
    sig=$(codesign -v "$f" 2>&1 && echo "SIGNED" || echo "UNSIGNED")
    echo "  [CRITICAL] $f [$sig]"
  fi
done || true)
if [ -n "$macho_hits" ]; then
  echo "$macho_hits"
else
  echo "  None found (good)"
fi

echo "=== Suspicious Files in /private/var/folders ==="
find /private/var/folders -type f \( -name "*.dylib" -o -name "*.so" -o -name "*.bundle" \) -maxdepth 5 2>/dev/null | head -20 | while read -r f; do
  sig=$(codesign -v "$f" 2>&1 && echo "SIGNED" || echo "UNSIGNED")
  echo "  $f [$sig]"
done || echo "  None found or permission denied"

echo "=== Executable Files in /tmp ==="
find /tmp -type f -perm +111 -maxdepth 3 2>/dev/null | head -20 | while read -r f; do
  echo "  $f ($(file -b "$f" 2>/dev/null | head -c 60))"
done || echo "  None found"

#!/bin/bash
set -e

# Standardize filenames: scan directory for files to rename
# Usage: standardize.sh [directory] [--recursive]
# Defaults to current directory, non-recursive

TARGET_DIR="${1:-.}"
TARGET_DIR=$(cd "$TARGET_DIR" 2>/dev/null && pwd) || { echo "Error: Invalid directory '$1'" >&2; exit 1; }
MAX_DEPTH=1

if [[ "$2" == "--recursive" || "$2" == "-r" ]]; then
  MAX_DEPTH=999
fi

echo "=== Filename Scan ==="

# Find files (exclude hidden files)
find "$TARGET_DIR" -maxdepth "$MAX_DEPTH" -type f -not -name ".*"

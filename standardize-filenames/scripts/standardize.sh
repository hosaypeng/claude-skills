#!/bin/bash
set -e

# Standardize filenames: scan directory for files to rename
# Usage: standardize.sh [directory] [--recursive]
# Defaults to current directory, non-recursive

TARGET_DIR="${1:-.}"
MAX_DEPTH=1

if [[ "$2" == "--recursive" || "$2" == "-r" ]]; then
  MAX_DEPTH=999
fi

# Find files (exclude hidden files)
find "$TARGET_DIR" -maxdepth "$MAX_DEPTH" -type f -not -name ".*"

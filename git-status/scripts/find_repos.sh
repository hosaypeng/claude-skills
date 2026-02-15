#!/bin/bash
set -e

# Find all git repos under $HOME, excluding noise directories
find "$HOME" -name ".git" -maxdepth 8 -type d 2>/dev/null \
  | grep -v "\.local/share" \
  | grep -v "\.gemini" \
  | grep -v "node_modules" \
  | grep -v "\.Trash" \
  | grep -v "Library/Caches" \
  | grep -v "\.claude/plugins"

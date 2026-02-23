#!/bin/bash
set -e

echo "=== Edit Habit ==="

BASE_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/Code/hosaypenggithubio"

if [ ! -d "$BASE_DIR" ]; then
  echo "Error: hosaypenggithubio directory not found at $BASE_DIR" >&2
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "Usage: run_edit_habit.sh <command> [args...]" >&2
  echo "Commands: add <category> <habit>, remove <habit>, rename <old> <new>" >&2
  exit 1
fi

cd "$BASE_DIR"
python3 scripts/edit_habit.py "$@"

#!/bin/bash
set -e

REPO_DIR="/Users/hsp/Library/Mobile Documents/com~apple~CloudDocs/Documents/Code/hosaypenggithubio"
HABITS_JSON="_data/habits.json"

echo "=== Parsing Habits ==="
cd "$REPO_DIR"
python3 scripts/parse_habits.py
echo "Parser finished successfully."

echo "=== Checking for Changes ==="
if git diff --quiet "$HABITS_JSON"; then
  echo "No habit changes detected."
  exit 0
fi

echo "Changes detected in $HABITS_JSON"

echo "=== Committing and Pushing ==="
git add "$HABITS_JSON"
git commit -m "Update habits

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push origin main
echo "Push to origin/main succeeded."

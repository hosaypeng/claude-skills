#!/bin/bash
set -e

echo "=== Preflight Context ==="

echo "--- Branch and File Status ---"
git status -sb 2>&1 || echo "Not a git repository" >&2

echo ""
echo "--- Summary of All Changes ---"
git diff --stat HEAD 2>&1 || echo "No commits or not a git repository" >&2

echo ""
echo "--- Full Diff ---"
git diff HEAD 2>&1 || echo "No commits or not a git repository" >&2

echo ""
echo "--- Recent Commits ---"
git log -3 --oneline 2>&1 || echo "No commits found" >&2

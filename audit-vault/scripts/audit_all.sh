#!/bin/bash
set -e

# --- Thin wrapper: every check lives in audit_vault.py (read-only, stdlib only) ---
# Usage: audit_all.sh [full|tags|frontmatter|links|orphans|relevance]
# VAULT overrides the vault path (default ~/Documents/obsidian).
# -B: no __pycache__ in the skills repo. -I: ignore PYTHON* env vars and user site.
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

python3 -B -I "$SCRIPTS_DIR/audit_vault.py" "$@"

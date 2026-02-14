#!/bin/bash
set -e

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================="
echo "  Obsidian Vault Audit — Full Report"
echo "========================================="
echo ""

bash "$SCRIPTS_DIR/check_tags.sh"
echo ""
echo "-----------------------------------------"
echo ""
bash "$SCRIPTS_DIR/check_frontmatter.sh"
echo ""
echo "-----------------------------------------"
echo ""
bash "$SCRIPTS_DIR/check_links.sh"
echo ""
echo "-----------------------------------------"
echo ""
bash "$SCRIPTS_DIR/check_orphans.sh"
echo ""
echo "========================================="
echo "  Audit Complete"
echo "========================================="

exit 0

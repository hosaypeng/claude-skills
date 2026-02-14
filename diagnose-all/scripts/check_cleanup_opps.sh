#!/bin/bash
set -e

echo "=== Cleanup Opportunities ==="

# User cache size
echo "User caches:"
du -sh ~/Library/Caches 2>/dev/null || echo "0"

# System cache size (requires admin)
echo ""
echo "System caches:"
du -sh /Library/Caches 2>/dev/null || echo "Unavailable"

# Logs size
echo ""
echo "Logs:"
du -sh ~/Library/Logs 2>/dev/null || echo "0"

# Trash size
echo ""
echo "Trash:"
du -sh ~/.Trash 2>/dev/null || echo "0"

# Downloads folder size
echo ""
echo "Downloads:"
du -sh ~/Downloads 2>/dev/null || echo "0"

# Large files in home directory (>100MB)
echo ""
echo "Large files (>100MB):"
find ~ -type f -size +100M 2>/dev/null | head -10 || echo "None found"

#!/bin/bash
set -e

echo "=== Test Coverage Scan ==="

echo "=== JS/TS Test Files ==="
find . -type f \( -name "*.test.*" -o -name "*.spec.*" -o -name "*_test.*" -o -name "test_*.*" \) \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) 2>/dev/null || echo "No JS/TS test files found"

echo ""
echo "=== Python Test Files ==="
find . -type f \( -name "*_test.py" -o -name "test_*.py" -o -name "*.test.py" -o -name "*.spec.py" \) 2>/dev/null || echo "No Python test files found"

echo ""
echo "=== Rust Test Files ==="
find . -type f \( -name "*_test.rs" -o -name "test_*.rs" \) 2>/dev/null
rg -l "#\[test\]|#\[cfg\(test\)\]" --type rust 2>/dev/null || echo "No Rust test files found"

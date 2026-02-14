#!/bin/bash
set -e

echo "=== Test Coverage Scan ==="

echo "--- JS/TS Test Files ---"
rg -l "describe|test|it\(" --type ts --type js 2>/dev/null || echo "No JS/TS test files found"

echo ""
echo "--- Python Test Files ---"
rg -l "def test_|class Test" --type py 2>/dev/null || echo "No Python test files found"

echo ""
echo "--- Rust Test Files ---"
rg -l "#\[test\]|#\[cfg\(test\)\]" --type rust 2>/dev/null || echo "No Rust test files found"

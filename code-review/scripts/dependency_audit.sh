#!/bin/bash
set -e

echo "=== Dependency Audit ==="

echo "=== npm (package.json / package-lock.json) ==="
git diff HEAD -- package.json package-lock.json 2>/dev/null || echo "No npm dependency changes"

echo ""
echo "=== Python (requirements.txt / Pipfile) ==="
git diff HEAD -- requirements.txt Pipfile* 2>/dev/null || echo "No Python dependency changes"

echo ""
echo "=== Rust (Cargo.toml / Cargo.lock) ==="
git diff HEAD -- Cargo.toml Cargo.lock 2>/dev/null || echo "No Rust dependency changes"

echo ""
echo "=== Go (go.mod / go.sum) ==="
git diff HEAD -- go.mod go.sum 2>/dev/null || echo "No Go dependency changes"

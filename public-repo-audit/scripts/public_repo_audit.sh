#!/bin/bash

# public-repo-audit: Validate repository is safe for public release
# Usage: public-repo-audit [repo_path]

set -euo pipefail

REPO_PATH="${1:-.}"
REPO_PATH=$(cd "$REPO_PATH" && pwd)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# Utility functions
check_pass() {
    echo -e "${GREEN}✅${NC} $1"
    ((PASS_COUNT++))
}

check_warn() {
    echo -e "${YELLOW}⚠️${NC}  $1"
    ((WARN_COUNT++))
}

check_fail() {
    echo -e "${RED}❌${NC} $1"
    ((FAIL_COUNT++))
}

header() {
    echo ""
    echo "================================════════════════════════════════════════"
    echo "  $1"
    echo "════════════════════════════════════════════════════════════════════════"
    echo ""
}

# Verify this is a git repo
if [ ! -d "$REPO_PATH/.git" ]; then
    echo -e "${RED}ERROR: Not a git repository: $REPO_PATH${NC}"
    exit 2
fi

cd "$REPO_PATH"

# Get repo info
REPO_NAME=$(basename "$REPO_PATH")
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                    📊 PUBLIC REPO AUDIT                              ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Repository: $REPO_NAME"
echo "Location:   $REPO_PATH"
echo "Branch:     $BRANCH"
echo "Commits:    $COMMIT_COUNT"
echo ""

# ====== CHECK 1: VENV RULE ======
header "✅ VENV RULE (on disk, never in git)"

if [ -d "$REPO_PATH/venv" ] || [ -d "$REPO_PATH/.venv" ] || [ -d "$REPO_PATH/env" ]; then
    check_pass "Virtual environment directory exists on disk"
else
    check_warn "No virtual environment directory found on disk (optional)"
fi

if git ls-files | grep -q "^venv/" 2>/dev/null; then
    check_fail "venv/ is tracked in git (should be excluded)"
else
    check_pass "venv/ not in git"
fi

if git ls-files | grep -q "^\.venv/" 2>/dev/null; then
    check_fail ".venv/ is tracked in git (should be excluded)"
else
    check_pass ".venv/ not in git"
fi

if git ls-files | grep -q "^env/" 2>/dev/null; then
    check_fail "env/ is tracked in git (should be excluded)"
else
    check_pass "env/ not in git"
fi

# ====== CHECK 2: SECRETS SCAN ======
header "✅ SECRETS SCAN"

# Pattern definitions
SECRET_PATTERNS=(
    "ANTHROPIC_API_KEY"
    "sk-ant-"
    "sk-proj-"
    "GITHUB_TOKEN"
    "ghp_"
    "AWS_ACCESS_KEY"
    "AKIA"
    "AWS_SECRET"
    "BEGIN RSA PRIVATE KEY"
    "BEGIN PRIVATE KEY"
    "-----BEGIN"
)

FOUND_SECRETS=0
for pattern in "${SECRET_PATTERNS[@]}"; do
    if git grep -i "$pattern" 2>/dev/null | head -1 | grep -q "$pattern"; then
        check_fail "Found pattern: $pattern"
        FOUND_SECRETS=$((FOUND_SECRETS + 1))
    fi
done

if [ $FOUND_SECRETS -eq 0 ]; then
    check_pass "No API keys or tokens detected"
    check_pass "No private keys detected"
    check_pass "No AWS credentials detected"
fi

# Check for .env files in git
if git ls-files | grep -q "\.env" 2>/dev/null; then
    check_fail ".env file is tracked in git (credentials will be exposed)"
else
    check_pass ".env files not in git"
fi

# ====== CHECK 3: PERSONAL INFO ======
header "✅ PERSONAL INFO"

# SSN pattern: XXX-XX-XXXX
if git grep -E "[0-9]{3}-[0-9]{2}-[0-9]{4}" 2>/dev/null | head -1 | grep -q ".*"; then
    check_fail "Possible SSN pattern found"
else
    check_pass "No SSN patterns detected"
fi

# Credit card: various patterns
if git grep -E "([0-9]{4}[ -]?){3}[0-9]{3,4}" 2>/dev/null | grep -qE "^[^:]*:[0-9]"; then
    check_warn "Possible credit card number detected (manual review recommended)"
else
    check_pass "No credit card patterns detected"
fi

# Check for email addresses (just warn, not a failure)
EMAIL_COUNT=$(git grep -E "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" 2>/dev/null | wc -l || echo "0")
if [ "$EMAIL_COUNT" -gt 0 ]; then
    check_warn "Found email addresses ($EMAIL_COUNT) - verify these are not personal"
else
    check_pass "No email addresses found"
fi

# ====== CHECK 4: FILE SIZE ======
header "✅ FILE SIZE"

LARGE_FILES=$(find "$REPO_PATH" -type f -size +10M ! -path "*/.git/*" ! -path "*/venv/*" 2>/dev/null | wc -l)
if [ "$LARGE_FILES" -gt 0 ]; then
    check_warn "Found $LARGE_FILES file(s) larger than 10MB"
    find "$REPO_PATH" -type f -size +10M ! -path "*/.git/*" ! -path "*/venv/*" 2>/dev/null | while read -r file; do
        size=$(du -h "$file" | cut -f1)
        echo "  - $file ($size)"
    done
else
    check_pass "No files larger than 10MB"
fi

# ====== CHECK 5: GITIGNORE ======
header "✅ .GITIGNORE VALIDATION"

GITIGNORE_PATH="$REPO_PATH/.gitignore"
if [ ! -f "$GITIGNORE_PATH" ]; then
    check_warn ".gitignore not found (should exclude venv, .env, __pycache__)"
else
    if grep -q "^venv/" "$GITIGNORE_PATH" 2>/dev/null; then
        check_pass "venv/ excluded in .gitignore"
    else
        check_fail "venv/ NOT in .gitignore"
    fi

    if grep -q "\.env" "$GITIGNORE_PATH" 2>/dev/null; then
        check_pass ".env excluded in .gitignore"
    else
        check_fail ".env NOT in .gitignore"
    fi

    if grep -q "__pycache__" "$GITIGNORE_PATH" 2>/dev/null; then
        check_pass "__pycache__/ excluded in .gitignore"
    else
        check_warn "__pycache__/ not in .gitignore"
    fi

    if grep -q "\.DS_Store" "$GITIGNORE_PATH" 2>/dev/null; then
        check_pass ".DS_Store excluded in .gitignore"
    else
        check_warn ".DS_Store not in .gitignore"
    fi
fi

# ====== CHECK 6: GIT HISTORY ======
header "✅ GIT HISTORY (last 20 commits)"

# Scan recent commits for secret patterns
COMMIT_SECRETS=0
for commit in $(git rev-list --max-count=20 HEAD 2>/dev/null); do
    if git show "$commit" 2>/dev/null | grep -qE "(api[_-]?key|secret|password|token)" 2>/dev/null; then
        check_warn "Commit $commit contains potential secret keywords"
        COMMIT_SECRETS=$((COMMIT_SECRETS + 1))
    fi
done

if [ $COMMIT_SECRETS -eq 0 ]; then
    check_pass "No secret patterns in recent commits"
fi

# ====== SUMMARY ======
echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"

if [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
    echo "║               🟢 READY FOR PUBLIC RELEASE                           ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "✅ All checks passed: $PASS_COUNT"
    echo ""
    echo "Next steps:"
    echo "  1. Change GitHub visibility to 'Public'"
    echo "  2. Consider adding SECURITY.md with responsible disclosure"
    echo "  3. Add CODE_OF_CONDUCT.md for community repos"
    echo ""
    exit 0

elif [ $FAIL_COUNT -eq 0 ]; then
    echo "║            🟡 WARNINGS FOUND - REVIEW BEFORE PROCEEDING              ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "✅ Passed: $PASS_COUNT  |  ⚠️  Warnings: $WARN_COUNT"
    echo ""
    echo "Review the warnings above before making this repo public."
    echo "Most warnings are informational and may be safe to ignore."
    exit 1

else
    echo "║            🔴 FAILURES FOUND - DO NOT MAKE PUBLIC YET               ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "✅ Passed: $PASS_COUNT  |  ⚠️  Warnings: $WARN_COUNT  |  ❌ Failures: $FAIL_COUNT"
    echo ""
    echo "FIX THESE ISSUES BEFORE MAKING THE REPO PUBLIC:"
    echo "  - Remove secrets and API keys"
    echo "  - Add venv/ and .env to .gitignore"
    echo "  - Remove accidentally committed files"
    echo ""
    exit 2
fi

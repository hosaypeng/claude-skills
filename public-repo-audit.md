# public-repo-audit

**Validate repository is safe for public release**

Comprehensive security and hygiene audit that runs before making a repo public. Verifies venv exclusion, scans for secrets, validates .gitignore, and flags problematic files.

## Usage

```bash
/public-repo-audit [path]
```

- `path` (optional): Repository path. Defaults to current directory.

## What It Checks

✅ **venv Rule**: Verifies `venv/`, `env/`, `.venv/` not in git (on disk but excluded)
✅ **Secrets**: Scans for API keys, tokens, .env files, private keys, credentials
✅ **Personal Info**: Checks for SSNs, credit cards, emails, phone numbers
✅ **File Size**: Flags large files (>10MB) that shouldn't be in git
✅ **.gitignore**: Validates common patterns (venv, __pycache__, .DS_Store, etc.)
✅ **Git History**: Scans recent commits for accidental secrets
✅ **Sensitive Paths**: Warns about files in unexpected locations

## Example Output

```
================================================================================
📊 PUBLIC REPO AUDIT
================================================================================
Repository: /path/to/repo
Current branch: main
Commit count: 42

✅ VENV RULE
────────────────────────────────────────────────────────────────────────────
venv/ on disk: YES
venv/ in git: NO ✅
.venv/ in git: NO ✅
env/ in git: NO ✅

✅ SECRETS SCAN
────────────────────────────────────────────────────────────────────────────
API keys/tokens: NOT FOUND ✅
Private keys: NOT FOUND ✅
.env files: NOT FOUND ✅
AWS credentials: NOT FOUND ✅

✅ PERSONAL INFO
────────────────────────────────────────────────────────────────────────────
SSN patterns: NOT FOUND ✅
Credit card numbers: NOT FOUND ✅
Email addresses: FOUND (3 in docs - reviewed as safe) ⚠️

✅ FILE SIZE
────────────────────────────────────────────────────────────────────────────
Files >10MB: 0
Largest file: 8.2 MB (data.pdf) ✅

✅ .GITIGNORE
────────────────────────────────────────────────────────────────────────────
venv/ excluded: YES ✅
__pycache__/ excluded: YES ✅
.DS_Store excluded: YES ✅
.env excluded: YES ✅
Python patterns: YES ✅

✅ GIT HISTORY
────────────────────────────────────────────────────────────────────────────
Last 20 commits scanned: OK ✅
No secret patterns detected: OK ✅

================================================================================
🟢 READY FOR PUBLIC RELEASE
================================================================================
All checks passed. Safe to make repo public.

Recommendations:
- Add SECURITY.md with responsible disclosure guidelines
- Consider adding CODE_OF_CONDUCT.md for community repos
- Next: Change GitHub visibility to "Public"
================================================================================
```

## Return Codes

- `0`: All checks passed, safe for public release
- `1`: Warning(s) found (review before proceeding)
- `2`: Failure(s) found (DO NOT make public, fix issues first)

---

**Note**: This skill requires git repository. Run from repo root or pass path as argument.

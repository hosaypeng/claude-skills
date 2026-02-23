---
name: audit-skills
description: "Scan all Claude skills for quality issues: inline bash that should be extracted to scripts, missing metadata, naming violations, broken cross-references, and script convention violations. Use when adding new skills, after refactoring skills, or periodically for hygiene."
user-invocable: true
---

# Audit Skills

Run the audit script to scan all skills for issues:

```bash
bash ~/.claude/skills/audit-skills/scripts/audit_skills.sh
```

If the script exits with a non-zero code, report the error and check whether the script exists and is executable.

## Interpreting Results

After running the script, review the output and categorize issues:

**Critical (fix now):**
- Missing SKILL.md
- Scripts not executable
- Cross-references to deleted skills

**Improvement (fix when touching the skill):**
- Inline bash blocks without `scripts/` directory
- Short descriptions missing trigger phrases
- Scripts missing `set -e` or shebang

**Naming (fix immediately):**
- Underscore names should be hyphenated

Present results as a table grouped by severity. If no issues found, confirm the skill library is clean.

## Troubleshooting

- **Script not found or not executable**: Verify `~/.claude/skills/audit-skills/scripts/audit_skills.sh` exists. Run `chmod +x` on it if needed.
- **Script outputs nothing**: All skills may be clean. Confirm by manually checking at least one skill directory.

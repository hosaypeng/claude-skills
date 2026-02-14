---
name: audit-skills
description: "Scan all Claude skills for quality issues: inline bash that should be extracted to scripts, missing metadata, naming violations, broken cross-references, and script convention violations. Use when adding new skills, after refactoring skills, or periodically for hygiene."
---

# Audit Skills

Run the audit script to scan all skills for issues:

```bash
bash ~/.claude/skills/audit-skills/scripts/audit_skills.sh
```

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

# Claude Skills Repository

This repo contains all Claude Code skills — reusable, slash-command-invocable workflows.

## Skill Architecture

Each skill is a directory containing:

- **`SKILL.md`** (required) — YAML frontmatter with `name`, `description`, `invocable: true`, plus orchestration instructions in markdown. This is the entry point Claude reads when the skill is invoked.
- **`scripts/`** (optional) — Bash scripts that do the heavy lifting. Keep logic here, not inline in SKILL.md.
- **`prompt.md`** (optional) — Extended prompt content separated from orchestration logic.

### Script Conventions

All scripts in `scripts/` must follow:

- Start with `#!/bin/bash` and `set -e`
- Use absolute paths (skills can be invoked from any working directory)
- Include section headers as comments for readability
- Write errors to stderr (`>&2`)
- Exit with non-zero on failure

### SKILL.md Structure

```yaml
---
name: skill-name
description: "One-line description with trigger phrases"
invocable: true
---
```

The description field must include trigger phrases so Claude knows when to invoke the skill (e.g., "Use when user says 'audit vault', 'check my notes'").

## Naming Conventions

- Directory names: **hyphenated** (`audit-vault`, not `audit_vault`)
- Script names: **hyphenated** (`run-audit.sh`, not `run_audit.sh`)
- Skill names in frontmatter must match the directory name exactly

## Adding a New Skill

1. Create a directory: `mkdir skill-name`
2. Create `skill-name/SKILL.md` with YAML frontmatter (`name`, `description`, `invocable: true`)
3. Add trigger phrases to the description field
4. If the skill needs shell logic, create `skill-name/scripts/` and add `.sh` files
5. Test the skill by invoking it with `/skill-name`
6. Run `/audit-skills` to validate

## Rules

- **Run `/audit-skills` after any changes** — catches missing metadata, naming violations, inline bash that should be extracted, and broken cross-references.
- **Descriptions must include trigger phrases** — without them, Claude won't know when to invoke the skill automatically. Use the pattern: `"... Use when user says 'phrase1', 'phrase2', ..."`.
- **No inline bash in SKILL.md** — extract anything over 3 lines to `scripts/`.
- **Keep skills focused** — one skill, one responsibility. Compose skills rather than building monoliths.

# Claude Skills Repository — AI Instructions

This repo contains all Claude Code skills — reusable, slash-command-invocable workflows.

## Skill Architecture

Each skill is a directory containing:

- **`SKILL.md`** (required) — YAML frontmatter with `name`, `description`, `invocable: true`, plus orchestration instructions in markdown. This is the entry point Claude reads when the skill is invoked.
- **`scripts/`** (optional) — Bash scripts that do the heavy lifting. Keep logic here, not inline in SKILL.md.
- **`references/`** (optional) — Detailed templates, format specs, and examples loaded on demand.

### Script Conventions

All scripts in `scripts/` must:

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

Include trigger phrases in the description so Claude knows when to invoke the skill (e.g., "Use when user says 'audit vault', 'check my notes'").

## Naming Conventions

- Name directories in **kebab-case** (`audit-vault`, not `audit_vault`).
- Name scripts in **kebab-case** (`run-audit.sh`, not `run_audit.sh`).
- Match the skill name in frontmatter to the directory name exactly.

## Adding a New Skill

1. Create a directory: `mkdir skill-name`
2. Create `skill-name/SKILL.md` with YAML frontmatter (`name`, `description`, `invocable: true`)
3. Add trigger phrases to the description field
4. IF the skill needs shell logic → THEN create `skill-name/scripts/` and add `.sh` files
5. IF SKILL.md exceeds ~800 words → THEN move templates to `skill-name/references/`
6. Include a Troubleshooting section with 2-4 likely failure modes
7. Test the skill by invoking it with `/skill-name`
8. Run `/audit-skills` to validate

## Rules

- Run `/audit-skills` after any changes.
- Include trigger phrases in every description — without them, Claude won't know when to invoke the skill automatically.
- IF bash logic exceeds 3 lines → THEN extract it to `scripts/`.
- Keep skills focused — one skill, one responsibility. Compose skills rather than building monoliths.

# Claude Code Skills Library

A collection of reusable skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code), Anthropic's agentic coding tool. Each skill encapsulates a specific workflow that Claude can invoke via slash commands.

## Skills

| Skill | Description |
|-------|-------------|
| `analyze-page` | Fetch and analyze full webpage content without summarization loss |
| `audit-skills` | Scan all skills for quality issues, naming violations, and broken references |
| `audit-vault` | Audit Obsidian vault for broken wikilinks, invalid tags, and missing frontmatter |
| `cleanup` | Remove Claude session artifacts, system caches, or forensic app traces |
| `code-review` | Expert code review with senior engineer lens (SOLID, security, tests) |
| `define-task` | Create well-defined autonomous task specs with acceptance criteria |
| `diagnose` | Run system diagnostics: full, security, hardware, or network mode |
| `edit-habit` | Add, remove, or rename habits in the Obsidian habit tracker |
| `explain` | Explain a file, folder, or codebase with terminal output and HTML slide deck |
| `extract-biodata` | Extract applicant biodata fields from PDFs into summary tables |
| `git-status` | Scan all local git repos for uncommitted changes and unpushed commits |
| `persist-state` | Save current agent work state for resumable workflows |
| `push` | Commit staged changes and push to GitHub remote |
| `recover` | Analyze agent failures and provide recovery strategies with rollback |
| `require-approval` | Create structured approval checkpoints for high-stakes decisions |
| `setup-benchmarks` | Scaffold testing and benchmark infrastructure for a project |
| `snapshot-env` | Capture a reproducible environment snapshot with exact versions |
| `standardize-filenames` | Standardize filenames to lowercase snake_case with ISO dates |
| `track-cost` | Analyze Claude agent resource usage and token consumption patterns |
| `update-habits` | Parse habits from Obsidian and push updated heatmap to GitHub Pages |

## Directory Convention

Each skill lives in its own directory under `skills/`:

```
skill-name/
  SKILL.md          # Orchestration file (required) — metadata + instructions
  scripts/          # Shell scripts for heavy lifting (optional)
    do_something.sh
  references/       # Verbose templates, format specs, examples (optional)
    output_format.md
```

- **`SKILL.md`** defines skill metadata (name, description, trigger phrases) and orchestration logic. Keep under ~800 words.
- **`scripts/`** contains executable shell scripts (`snake_case.sh`, `#!/bin/bash`, `set -e`). All bash logic goes here, not inline in SKILL.md.
- **`references/`** holds verbose content (output templates, naming conventions, CSS/JS blocks) that SKILL.md references by path.

## Links

- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Claude Code skills guide](https://docs.anthropic.com/en/docs/claude-code/skills)

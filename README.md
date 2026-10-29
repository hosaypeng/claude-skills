# Claude Code Skills Library

A collection of reusable skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code), Anthropic's agentic coding tool. Each skill encapsulates a specific workflow that Claude can invoke via slash commands.

## Skills

| Skill | Description |
|-------|-------------|
| `audit-paths` | Scan CLAUDE.md, memory files and LaunchAgent plists for dead file and directory paths |
| `audit-vault` | Read-only audit of the Obsidian vault: broken wikilinks, invalid tags, frontmatter schema, orphans, file naming |
| `clean-caches` | Report and clear regenerable app caches via the `clean_caches` command |
| `git-status` | Scan all local git repos for uncommitted changes and unpushed commits |
| `health-check` | Pass/fail sweep of LaunchAgents, git repos, vault, recovery-repo drift and config sync |
| `ocr` | OCR a scanned PDF or image locally with GLM-OCR (Ollama) into a Markdown file |
| `persist-state` | Save current agent work state for resumable workflows |
| `push` | Commit staged changes and push to GitHub remote |
| `update-dependencies` | After vault moves, renames or deletions, find stale references in config, hooks, scripts, LaunchAgents, memory and wikilinks |

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

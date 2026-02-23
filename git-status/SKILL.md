---
name: git-status
description: "Scan all local git repositories for uncommitted changes and unpushed commits. Use when user says 'check my repos', 'git status all', 'any unpushed changes', 'repo health check', or 'what needs committing'."
user-invocable: true
argument-hint: "[repo path] (optional - defaults to all repos)"
---

# Git Status Checker

Check the commit and push status of all git repos under `$HOME`.

## Instructions

1. Run the repo discovery script to find all git repos, excluding noise directories:

```bash
bash ~/.claude/skills/git-status/scripts/find_repos.sh
```

   If find_repos.sh fails, fall back to `find ~ -name .git -type d -maxdepth 5` excluding node_modules and .cache.

2. For each repo found, check two things:

- **Uncommitted changes:** `git -C <repo> status -s 2>/dev/null`
- **Unpushed commits:** `git -C <repo> log @{u}.. --oneline 2>/dev/null`

3. Report a summary grouped into:

- **Clean repos** — nothing uncommitted, nothing unpushed (just list names)
- **Repos with uncommitted changes** — show file count and repo path
- **Repos with unpushed commits** — show commit count and repo path

Use `~` shorthand for `$HOME` in paths for readability. Keep output concise.

## Troubleshooting

- **Repo discovery takes very long**: The script may be traversing large directories. Verify it excludes node_modules, .cache, and Library.
- **"fatal: not a git repository" for some paths**: Skip corrupted repos and note them in output.
- **No upstream configured**: Skip the unpushed check for those repos and note "no upstream configured."

---
name: git-status
description: "Scan all local git repositories for uncommitted changes, unpushed commits, and stale branches. Use when user says 'check my repos', 'git status all', 'any unpushed changes', 'repo health check', 'stale branches', or 'what needs committing'."
user-invocable: true
argument-hint: "[repo path] (optional - defaults to all repos)"
---

# Git Status Checker

Check the commit, push, and branch health of all git repos under `$HOME`.

## Instructions

1. Run the repo discovery script to find all git repos, excluding noise directories:

```bash
bash ~/.claude/skills/git-status/scripts/find_repos.sh
```

   If a specific repo path was provided as an argument, pass it through for the single-repo fast path:

```bash
bash ~/.claude/skills/git-status/scripts/find_repos.sh /path/to/repo
```

   If find_repos.sh fails, fall back to `find ~ -name .git -type d -maxdepth 5` excluding node_modules and .cache.

2. For each repo found, check three things:

- **Uncommitted changes:** `git -C <repo> status -s 2>/dev/null`
- **Unpushed commits:** `git -C <repo> log @{u}.. --oneline 2>/dev/null`
- **Stale branches:** `bash ~/.claude/skills/git-status/scripts/stale_branches.sh <repo> 7`

3. Report a summary grouped into:

- **Clean repos** — nothing uncommitted, nothing unpushed, no stale branches (just list names)
- **Repos with uncommitted changes** — show file count and repo path
- **Repos with unpushed commits** — show commit count and repo path
- **Repos with stale branches** — show branch name, last commit date, and age in days. Format as a table:

```
| Repo   | Branch          | Last commit | Age  |
| ------ | --------------- | ----------- | ---- |
| ~/Code/foo | feature/old  | 2026-02-15  | 22d  |
```

   Skip `main` and `master` from the stale branch report — they may be inactive but are not candidates for cleanup.

Use `~` shorthand for `$HOME` in paths for readability. Keep output concise.

## Troubleshooting

- **Repo discovery takes very long**: The script may be traversing large directories. Verify it excludes node_modules, .cache, and Library.
- **"fatal: not a git repository" for some paths**: Skip corrupted repos and note them in output.
- **No upstream configured**: Skip the unpushed check for those repos and note "no upstream configured."
- **Stale branch script returns nothing**: All branches have recent commits — this is normal. Only report the stale branches section if there are results.

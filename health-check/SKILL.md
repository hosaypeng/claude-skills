---
name: health-check
description: "Check system health across LaunchAgents, git repos, vault backup, habits pipeline, recovery-repo drift, and security IOC freshness. Only alerts on failures. Use when user says 'health check', 'is everything working', 'check my systems', or 'anything broken'."
user-invocable: true
---

# Health Check

`/health-check` = fast pass/fail sweep of your own automation (~5 s). `/diagnose` = deep hardware/security analysis. `/threat-hunt` = nation-state and credential-theft hunt.

Run the script:

```bash
bash ~/.claude/skills/health-check/scripts/run_health_check.sh
```

It takes no arguments and sends no alerts. Every line starts with `OK`, `WARN`, `FAIL` or `SKIP`; every section runs even if an earlier one fails.

## What it checks

- **LaunchAgents**: every user-installed agent in `~/Library/LaunchAgents` (Apple, Google and Homebrew plists are skipped). Reports not-loaded agents as FAIL and a non-zero last exit status as WARN — a crashing agent is otherwise invisible.
- **Git repos**: uncommitted or unpushed changes in `~/Code/*`, the vault (`~/Documents/obsidian`) and `~/.claude/skills`. A repo with no upstream is reported as `no-upstream`, never as clean.
- **Vault**: is `~/Documents/obsidian` accessible, note count.
- **Habits pipeline**: is `habits.json` in the GitHub Pages repo older than the newest `all_habits*.md` in the vault? Age alone is not a failure — an untouched source means there is nothing to push.
- **Path audit**: runs `audit-paths` — dead paths in CLAUDE.md, MEMORY.md, memory files, LaunchAgent plists.
- **Recovery repo drift**: `brew leaves` / casks missing from the Brewfile; `~/Code` repos missing from or stale in `repos.txt`.
- **Large log files**: any `.log` over 100MB under `~/Code`, `~/Jts`, `~/.claude`, `~/.hermes`, `~/.cache`.
- **Claude config sync**: is `com.hsp.sync-claude-config` loaded; do `settings.json`, hooks and commands match the recovery repo?
- **Security IOC lists**: age of every `ioc_*.txt` in `~/Code/diagnose/references` and `~/Code/threat-hunt/references`. WARN at 90 days — a stale list means that skill's IOC category is unverified.

## CLAUDE.md audit

After the script, manually verify both CLAUDE.md files:

1. **`~/.claude/CLAUDE.md`** — Check that any referenced skill names still exist in `~/.claude/skills/`.
2. **Vault `CLAUDE.md`** — For each concrete path referenced (vault dirs, templates, quick references, related repos):
   - Verify the path exists on disk
   - Verify the tag list matches `40_indexes/*.md` (excluding `_index.md`)
   - Verify template names match `templates/*.md`
3. Report any stale references found. Auto-fix non-destructive issues (update counts, fix paths). Ask before removing rules or references.

## Interpreting results

- If all checks pass (script + CLAUDE.md audit), report "All systems healthy".
- Otherwise present failures grouped by section, each with its remediation:
  - not-loaded agent → `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/<name>.plist`
  - agent with non-zero exit → read its StandardErrorPath log, then decide whether to fix or `launchctl bootout` it
  - unpushed / uncommitted → `git -C <repo> push` or commit; `no-upstream` → `git push -u origin <branch>`
  - stale habits.json → `/update-habits`
  - dead paths → `/audit-paths`
  - Brewfile / repos.txt drift → edit the file in `~/Code/macos-recovery-setup`
  - large log → inspect, then trash or rotate it (`/cleanup` does not touch logs under `~/Code`)
  - stale IOC list → refresh from the sources named in the file header, save under a new dated filename
- A WARN for a repo you deliberately keep local-only (no remote) is informational; say so rather than nagging.

## Scheduling

Not scheduled. It runs only when invoked. To run it daily, create a LaunchAgent with `StartCalendarInterval` pointing at the script and a `StandardOutPath` log; the script's exit code is always 0, so grep the log for `^(WARN|FAIL)` to detect problems.

## See also

- **`/git-status`** — repo-by-repo detail (stale branches, dirty trees). Health-check only counts.
- **`/audit-paths`** — the dead-path table with suggested fixes.
- **`/cleanup`** — orphaned LaunchAgents surfaced here are handled by `cleanup forensic`.

## Troubleshooting

- **`brew leaves` slow**: first run takes a few seconds; subsequent runs are cached.
- **Agent reported as "not loaded" but the plist exists**: it was never bootstrapped, or `launchctl bootout` was run. Bootstrap it as above.
- **Agent shows exit status 1 with no obvious error**: check the plist's `StandardErrorPath`; if it points to `/dev/null`, add a log path before debugging.

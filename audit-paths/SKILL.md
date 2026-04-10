---
user-invocable: true
name: audit-paths
description: "Scan CLAUDE.md, MEMORY.md, memory files, and LaunchAgent plists for dead file/directory paths. Use when user says 'audit paths', 'check for dead paths', 'stale references', or after restructuring files/directories."
argument-hint: "[memory|launchagents|all]"
---

# Audit Paths

Parse the argument to determine which mode to run:

- **`all`** (or no argument) — scan memory/config files AND LaunchAgent plists
- **`memory`** — only scan CLAUDE.md, MEMORY.md, and memory/*.md
- **`launchagents`** — only scan ~/Library/LaunchAgents/*.plist

## Execution

```bash
bash ~/.claude/skills/audit-paths/scripts/audit_paths.sh <mode>
```

## Presenting Results

After running the script, present results as a table:

| Status | Source File | Dead Path |
|--------|------------|-----------|

For each dead path found, suggest a specific fix:
- If the path looks like a renamed file/dir, suggest the likely new path
- If the path looks deleted, suggest removing the reference
- If it's a LaunchAgent, suggest updating the plist or unloading the agent

If no dead paths are found, confirm all paths are valid.

## Troubleshooting

- **Script exits with non-zero code**: Exit code = number of dead paths found. This is expected — not an error.
- **False positives for relative paths**: The script resolves relative paths against the vault root. If a path is relative to a different base, it may false-positive.
- **LaunchAgent paths that look dead but work**: Some plists reference paths created at runtime (log dirs, PID files). Verify before fixing.
- **Permission denied on LaunchAgents**: iCloud-managed plists may have restricted permissions. Run with standard user permissions — don't sudo.

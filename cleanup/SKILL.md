---
name: cleanup
description: "Remove Claude session artifacts, system caches, or forensic app traces. Use '/cleanup session' after Claude work, '/cleanup system' for disk space, '/cleanup forensic' for privacy after uninstalling apps, or '/cleanup' to run all."
argument-hint: "[session|system|forensic|all]"
---

# Unified Cleanup Skill

You are executing the `/cleanup` skill. This skill consolidates session artifact cleanup, system cache cleanup, and forensic trace cleanup into a single command with modes.

## Argument Parsing

Parse the user's argument to determine the mode:

| Argument | Mode | Script |
|----------|------|--------|
| `session` | Session artifacts only | `cleanup_session.sh` |
| `system` | System caches only | `cleanup_system.sh` |
| `forensic` | Forensic traces only | `cleanup_forensic.sh` |
| `all` | All three in sequence | `cleanup_all.sh` |
| *(none)* | All three in sequence | `cleanup_all.sh` |

**Script directory**: `~/.claude/skills/cleanup/scripts/`

## Execution

1. Determine the mode from the argument (default = `all`)
2. Run the corresponding script from `~/.claude/skills/cleanup/scripts/`
3. Capture and present the output to the user
4. Analyze results and highlight important findings

## Mode Details

### Session Mode (`/cleanup session`)
Removes Claude-specific session artifacts:
- Scratchpad directories under `/private/tmp/claude-*`
- Orphaned Claude processes (detected but not killed automatically)
- Stale lock files in `/tmp/`
- Temporary/partial downloads

### System Mode (`/cleanup system`)
Frees disk space by clearing caches:
- User library caches (preserves files modified in last 7 days)
- Browser caches (Chrome, Safari, Firefox)
- Development caches (Homebrew, npm, pip, Xcode DerivedData)
- System temp files and partial downloads
- Old logs (30+ days)

### Forensic Mode (`/cleanup forensic`)
Removes privacy-sensitive traces left by uninstalled apps:
- Quarantine events database (download history)
- KnowledgeC database (app usage history)
- CoreDuet database (interaction patterns)
- Recent items and Spotlight shortcuts
- Launch Services database rebuild
- Orphaned app data (saved state, containers, group containers, HTTPStorages)
- Orphaned LaunchAgents (background services referencing missing executables)
- Crash reports and diagnostic logs
- Siri suggestions data

## Safety Rules

1. **NEVER delete without showing what will be deleted first**
2. **ASK user confirmation before deleting anything over 1GB**
3. **SKIP any directory that doesn't exist**
4. **PRESERVE files modified in the last 7 days** (in system cache mode)
5. **NEVER delete** user documents, app binaries, config files, keychains, or active files
6. **NEVER recommend granting Full Disk Access to Terminal** — for TCC-protected files, recommend Finder deletion instead
7. **Handle locked files gracefully** — report them, do not error out
8. **Deep orphan detection is mandatory** — always cross-reference against installed app bundle IDs before flagging as orphan

## Presentation

After running the script(s), present the user with:
1. A clear summary of what was cleaned per category
2. Total disk space recovered
3. Any items that could not be removed (with explanation)
4. Manual steps required for TCC-protected items (if applicable)
5. Log file location(s) for reference

## Log Files

Each mode appends to its own log:
- Session: `~/.claude/cleanup-log.txt`
- System: `~/.claude/system-cleanup-log.txt`
- Forensic: `~/.claude/purge-artifacts-log.txt`

Execute the cleanup now based on the provided mode argument.

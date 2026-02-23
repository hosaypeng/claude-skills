# Cleanup Mode Details

## Session Mode (`/cleanup session`)
Removes Claude-specific session artifacts:
- Scratchpad directories under `/private/tmp/claude-*`
- Debug logs older than 7 days (`~/.claude/debug/`)
- Claude desktop app cache (`~/Library/Application Support/Claude/Cache/`)
- Old VM bundles — keeps only the latest (`~/Library/Application Support/Claude/vm_bundles/`)
- Stale project caches older than 30 days (`~/.claude/projects/`)
- Old backup files older than 30 days (`~/.claude/backups/`)
- Session caches older than 30 days (file-history, image-cache, paste-cache)
- Orphaned Claude processes (detected but not killed automatically)
- Stale lock files in `/tmp/`
- Temporary/partial downloads

## System Mode (`/cleanup system`)
Frees disk space by clearing caches:
- User library caches (preserves files modified in last 7 days; **skips browsers, messaging apps, and daily-use apps**)
- Browser caches — Chrome, Safari, Firefox (**reported only**, not auto-deleted — clearing degrades daily performance)
- Development caches: Homebrew, npm, pip, uv, Yarn, pnpm, Go, Cargo, Maven, Gradle, CocoaPods, Composer, Ruby Bundler, Xcode DerivedData
- Sandboxed app caches — **Apple apps only** (`com.apple.*`); third-party app caches are skipped (may contain auth/session tokens)
- App-specific caches (Discord, VS Code, Slack, Zoom cache dir only)
- Application Support logs and caches (scans all `~/Library/Application Support/*/` subdirs for Cache/Logs/GPUCache; **skips Claude, obsidian, Apple, Knowledge, MobileSync**)
- Xcode Archives and CoreSimulator (reported, not auto-deleted)
- Docker disk usage (reported, not auto-deleted)
- iOS device backups (reported, not auto-deleted)
- System temp files and partial downloads
- Old logs (30+ days)
- Time Machine local snapshots (reported, not auto-deleted)
- Current Trash size (reported, never auto-emptied)

## Purge Mode (`/cleanup purge`)
Removes stale build artifacts from project directories:
- `node_modules`, `.next`, `target`, `.build`
- `__pycache__`, `.pytest_cache`, `.mypy_cache`, `.ruff_cache`, `.tox`
- `.venv`, `venv` (Python virtualenvs)
- `.gradle`, `.parcel-cache`, `.turbo`, `.angular`, `.nuxt`, `.svelte-kit`, `.expo`

Generic names (`build`, `dist`, `.output`, `coverage`) are excluded — too often git-tracked or intentional. Git-tracked directories are always skipped.

Only targets artifacts older than 30 days and larger than 1MB. Scan paths are configured in `~/.claude/cleanup-purge-paths.txt` (one directory per line). Defaults to `~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Code`, `~/Projects`, `~/Code`, `~/dev`, `~/GitHub`, `~/Repos`.

## Forensic Mode (`/cleanup forensic`)
Removes privacy-sensitive traces left by uninstalled apps:
- Quarantine events database (download history)
- KnowledgeC database (app usage history)
- CoreDuet database (interaction patterns)
- Recent items and Spotlight shortcuts
- Launch Services database rebuild
- Orphaned app data (saved state, group containers, HTTPStorages, Application Support)
- Orphaned containers (reported — SIP-protected, requires Finder to delete)
- Orphaned preferences (flagged for review — some belong to CLI tools)
- Orphaned LaunchAgents (background services referencing missing executables)
- Login items referencing deleted apps (reported for manual review)
- Third-party kernel extensions (reported, requires sudo)
- Crash reports and diagnostic logs
- Siri suggestions data

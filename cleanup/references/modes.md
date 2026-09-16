# Cleanup Mode Details

## Session Mode (`/cleanup session`)
Removes Claude-specific session artifacts:
- Scratchpad directories under `/private/tmp/claude-*`
- Debug logs older than 7 days (`~/.claude/debug/`)
- Claude desktop app cache (`~/Library/Application Support/Claude/Cache/`)
- Old VM bundles — keeps only the latest (`~/Library/Application Support/Claude/vm_bundles/`)
- Stale project caches older than 30 days (`~/.claude/projects/`). Projects holding auto-memory (a non-empty `memory/` subdirectory) are always preserved — memory is written to persist across sessions and has no other copy.
- Old backup files older than 30 days (`~/.claude/backups/`)
- Session caches older than 30 days (file-history, image-cache, paste-cache)
- Orphaned Claude processes (detected but not killed automatically)
- Stale lock files in `/tmp/`
- Temporary/partial downloads

## System Mode (`/cleanup system`)
Frees disk space by clearing caches:
- User library caches (preserves files modified in last 7 days; **skips browsers, messaging apps, and daily-use apps**)
- Browser caches — Chrome, Safari, Firefox (**reported only**, not auto-deleted — clearing degrades daily performance)
- Development caches, auto-deleted: Homebrew, npm, npx, pip, uv, Yarn, pnpm, Go, CocoaPods, Composer, Ruby Bundler, Xcode DerivedData, Playwright
- Expensive dev caches, **reported only**: `~/.cache/huggingface` (multi-GB model re-downloads), `~/.cargo/registry`, `~/.gradle/caches`, and `~/.m2/repository` — the Maven repository can hold locally-built artifacts (`mvn install`) that exist nowhere else and cannot be re-downloaded
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

Only targets artifacts older than 30 days and larger than 1MB. Scan paths are configured in `~/.claude/cleanup-purge-paths.txt` (one directory per line). Defaults to `~/Code`, `~/Projects`, `~/dev`, `~/GitHub`, `~/Repos`.

## Forensic Mode (`/cleanup forensic`)
Removes privacy-sensitive traces left by uninstalled apps:
- Quarantine events database (download history)
- KnowledgeC database (app usage history)
- CoreDuet database (interaction patterns)
- Recent items and Spotlight shortcuts
- Launch Services database rebuild

### Category B — orphan detection is REPORT ONLY

Saved state, containers, group containers, HTTPStorages, WebKit data, Application Support, preferences, Application Scripts, and caches are **listed for review and never deleted**.

This category previously auto-deleted and destroyed live data for Google Drive, WhatsApp, Zoom, and Apple Shortcuts while all four were installed and running, plus Find My settings (`systemgroup.com.apple.icloud.searchpartyd.sharedsettings.plist`) and the Apple Wallet cache. The cause is structural, not a one-off: deletion was deny-listed, so anything a hand-maintained skip list failed to name was deleted by default.

Matching is now deliberately generous — it protects on any of:
1. Prefix match in either direction after normalization (team ID, `group.`, and `systemgroup.` prefixes stripped)
2. Shared vendor namespace, first two components (`net.whatsapp.family` ← `net.whatsapp.WhatsApp`)
3. A distinctive token (5+ chars) appearing in any installed bundle ID or app name
4. For dot-less names only, a vendor token from an installed app appearing inside it (`ZoomClient3rd` ← `us.zoom.xos`)

Additional guards: anything modified in the last 30 days is never flagged (a live app rewrites its support files constantly, which catches false positives regardless of name matching); anything resolving to a command on `PATH` is never flagged (CLI tools own no `.app` bundle); dot-less preference files are never flagged (app preferences are always named by bundle ID).

Wrongly protecting a real orphan costs one line of output. Wrongly flagging a live app cost real data.
- Orphaned LaunchAgents (background services referencing missing executables)
- Login items referencing deleted apps (reported for manual review)
- Third-party kernel extensions (reported, requires sudo)
- Crash reports and diagnostic logs
- Siri suggestions data

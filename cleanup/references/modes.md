# Cleanup Mode Details

All modes share `scripts/_helpers.sh`: every deletion is `safe_trash` / `safe_trash_contents`, which applies — in order — the protection list (`references/protected_patterns.txt`), the whitelist (`~/.claude/cleanup-whitelist.txt`), dry-run, and the per-item operations log (`~/.claude/cleanup-operations.log`). `--dry-run` on any mode writes `~/.claude/cleanup-preview.txt` instead of moving anything.

## Session Mode (`/cleanup session`)
Removes Claude-specific session artifacts:
- Scratchpad directories under `/private/tmp/claude-*` (skips the current session, any directory holding a live Unix socket such as the MCP browser bridge, and anything modified in the last 24h)
- Debug logs older than 7 days (`~/.claude/debug/`)
- Claude desktop app cache (`~/Library/Application Support/Claude/Cache/`)
- Old VM bundles — keeps only the latest `*.bundle` (`~/Library/Application Support/Claude/vm_bundles/`); the `warm/` staging dir is not a bundle and is left alone
- Stale project caches older than 30 days (`~/.claude/projects/`). Projects holding auto-memory (a non-empty `memory/` subdirectory) are always preserved — memory is written to persist across sessions and has no other copy; `~/.claude/projects/*/memory*` is also on the protection list.
- Old backup files older than 30 days (`~/.claude/backups/`)
- Session caches older than 30 days (file-history, image-cache, paste-cache)
- Orphaned Claude processes (detected but not killed automatically)
- Stale lock files in `/tmp/`
- Temporary/partial downloads

## System Mode (`/cleanup system`)
Frees disk space by clearing caches:
- **User library caches** (`~/Library/Caches/*`, preserves anything modified in the last 7 days). Apple caches are skipped except an allowlist of pure regenerable content (`com.apple.helpd`, `QuickLook.thumbnailcache`, `iconservices`, `photoanalysisd`, `rosetta.update`, `amp.mediasevicesd`, `WebKit.Networking`). Browsers, messaging, and proxy caches are on the protection list. Each remaining cache is checked against the live process table (`cache_owner_running`) and skipped when its owner is running **or the state is unknown**. `Homebrew`, `pip`, `pypoetry`, `composer`, `org.swift.swiftpm`, `ms-playwright*` are skipped here and handled surgically below.
- **Browser caches** — Chrome, Safari, Firefox, Brave (**reported only**, not auto-deleted — clearing degrades daily performance)
- Stale Chrome framework versions inside `Google Chrome.app` are **never touched** — Mole (`mo clean`) deletes them, but that edits an app binary and can break the bundle signature
- **GoogleUpdater**: `crx_cache` contents auto-deleted when idle >7 days; updater version dirs other than the `Current` symlink target auto-deleted
- **Saved Application State**: `*.savedState` idle >30 days auto-deleted (window layouts regenerate on next launch)
- **Development caches, auto-deleted** (contents only, directory kept): Homebrew `downloads/` only (`api/`, `bootsnap/`, `locks/` are the formula index and load cache every `brew` call reads), pip, npm (`_cacache`, `_npx`, `_logs`, `_prebuilds`), yarn, pnpm store, corepack, bun, turbo, typescript/electron/node-gyp/vite/webpack/eslint/prettier/puppeteer caches, uv, ruff, mypy, poetry (`artifacts`, `cache` — never `virtualenvs`), pre-commit, pyenv cache, CocoaPods, Composer, Bundler, gem specs, Go module cache, rustup downloads, SwiftPM, Docker buildx, kube/aws/gcloud/azure CLI caches and logs, curl/wget, oh-my-zsh cache, Playwright browsers, Xcode DerivedData
- **Partial deletes of expensive trees** (guarded by an idle check on `cargo`/`rustc`, `gradle`/`java`): `~/.cargo/registry/cache` (compressed crate downloads) is trashed while `registry/src` and `git/` stay report-only; `~/.gradle/{daemon,workers,notifications}` and `caches/build-cache-*` are trashed while `caches/modules-*` (the dependency store) stays report-only
- **Xcode**: `{iOS,watchOS,tvOS,visionOS} DeviceSupport` keeps the newest two versions; `~/Library/Logs/CoreSimulator` and `~/Library/Caches/com.apple.dt.Xcode` are trashed — all only when Xcode, xcodebuild, xctest, XCTRunner, Simulator and XCBBuildService are conclusively idle. Archives and CoreSimulator are reported only; `xcrun simctl delete unavailable` is printed as a hint
- **Claude Code native versions** (`~/.local/share/claude/versions/`): every version except the one `~/.local/bin/claude` resolves to is auto-deleted, no idle threshold. Skipped entirely if the symlink is missing or resolves elsewhere
- **Claude Desktop bundled runtimes** (`~/Library/Application Support/Claude/claude-code/`, `claude-code-vm/`): all but the highest version **reported only** — nothing on disk names the active one
- Auto-updater download caches (`~/Library/Application Support/Caches/*-updater`, e.g. `cursor-updater`, `cron-updater`) — auto-deleted when idle >30 days; regenerate on next update check
- **Abandoned dotdirs**: two tiers. Dotdirs on the explicit `REGENERABLE_DOTDIRS` allowlist in `cleanup_system.sh` (agent/CLI tool state: `.codex`, `.cursor`, `.hermes`, `.interpreter`, `.paperclip`, etc.) are **auto-deleted when idle >180 days**. Everything else is report-only. `.gnupg`, `.ollama`, `.lmstudio` are in `ACTIVE_DOTDIRS` and never flagged
- **Expensive dev caches, reported only**: `~/.cache/huggingface` (multi-GB model re-downloads), `~/.cargo/registry/src`, `~/.gradle/caches/modules-*`, `~/.m2/repository` (can hold locally-built `mvn install` artifacts that exist nowhere else), `~/.ivy2/cache`, `~/.nuget/packages`
- **Sandboxed app caches** — **Apple apps only** (`com.apple.*`), each gated by `cache_owner_running` on the container ID, except always-resident analysis daemons (`mediaanalysisd`, `photoanalysisd`, `geod`, `AMPArtworkAgent`, `AppleMediaServices`) whose derived caches are cleared even while running; third-party app caches are skipped (may contain auth/session tokens)
- **App-specific caches** (Discord, VS Code incl. `CachedExtensionVSIXs`, Slack, Zoom cache dir only) — only when the app is conclusively idle
- **Application Support logs and caches** (scans `~/Library/Application Support/*/` up to 2 levels deep). Chromium leaves — `Code Cache`, `GPUCache`, `GPUPersistentCache`, `DawnCache`, `GrShaderCache`, `GraphiteDawnCache`, `DawnGraphiteCache`, `DawnWebGPUCache`, `Crashpad/completed` — and `logs`/`Logs` are always eligible. A directory merely *named* `Cache`, `Caches` or `CachedData` is only eligible when a Chromium marker (`Code Cache` or `GPUCache`) sits beside it — proof of an Electron layout rather than an app using "Cache" for real data. Electron layouts (including per-profile ones like `Codex/Default/GPUCache`) are skipped entirely while the app's process is running or its state is unknown. `Google` (report-only in the browser section) and `Claude` (session mode's responsibility) are skipped by name; everything else is gated by the protection list
- Claude debug/telemetry and Gemini tmp dirs
- Incomplete downloads in `~/Downloads` (`*.tmp`, `*.crdownload`, `*.part`, `*.partial`, `*.download`) — skipped while `lsof` shows the file open
- iOS device backups (reported, not auto-deleted); `.ipsw` firmware images in `~/Library/iTunes/* Software Updates` trashed
- Old logs (30+ days)
- Time Machine local snapshots (reported, not auto-deleted)
- Current Trash size (reported, never auto-emptied)

## Purge Mode (`/cleanup purge`)
Removes stale build artifacts from project directories:
- `node_modules`, `.next`, `.nuxt`, `.output`, `target`, `.build`
- `__pycache__`, `.pytest_cache`, `.mypy_cache`, `.ruff_cache`, `.tox`, `.nox`, `.eggs`
- `.venv`, `venv` (Python virtualenvs)
- `.gradle`, `.parcel-cache`, `.turbo`, `.angular`, `.svelte-kit`, `.astro`, `.expo`, `.terragrunt-cache`, `.zig-cache`, `zig-out`, `.cxx`, `Pods`, `.dart_tool`
- `bin` — only a .NET build output: a `*.csproj`/`.fsproj`/`.vbproj` sibling **and** a `Debug/` or `Release/` child. Go and script projects keep sources in `bin/`
- `vendor` — only Composer's (`composer.json` sibling). Go and Rails `vendor/` is source
- Any directory carrying a valid `CACHEDIR.TAG` (`Signature: 8a477f597d28d172789f06886806bc55`), whatever it is named — the standard marker tools drop to declare a regenerable cache

Generic names (`build`, `dist`, `coverage`) are excluded — too often git-tracked or intentional.

Guards, in order:
- **Cloud-synced paths are never purged.** Decided on the physical path, so the `~/gdrive-*` symlinks resolve correctly: `~/Library/CloudStorage/*`, `Mobile Documents`, `~/My Drive*`, `~/Google Drive*`, `~/Dropbox*`, `~/OneDrive*`, `~/Sync`, `~/iCloud Drive*`. Mole only applies this in non-interactive mode; here it is unconditional.
- Age: artifact directory untouched for 30 days.
- **Git**: skipped if it contains a `.git` (a project of its own) or if `git ls-files` finds *any* tracked file inside it — the old check only caught the artifact directory itself being tracked.
- Size ≥1MB (unknown size still qualifies).

Scanning uses `fd` when installed (hidden dirs, ignore files disabled, matched trees pruned, depth 6), else `find` with `-prune`. Scan paths are configured in `~/.claude/cleanup-purge-paths.txt` (one directory per line). Defaults: `~/Code`, `~/Projects`, `~/dev`, `~/GitHub`, `~/Repos`, `~/Workspace`, `~/Development`, `~/.claude/worktrees`, `~/.codex/worktrees`.

Centralized venvs in `~/.venvs/` are auto-deleted when nothing inside them has been written in >90 days (activation and installs both leave fresh mtimes). Younger ones are listed as "in use — kept". Whitelist a venv path to keep it regardless of age.

## Forensic Mode (`/cleanup forensic`)
Removes privacy-sensitive traces left by uninstalled apps:
- Quarantine events database (download history) - report only
- KnowledgeC database (app usage history) - report only
- Recent items: the `Recent*` lists and every per-app list in `ApplicationRecentDocuments/` (`.sfl2`/`.sfl3`/`.sfl4`). The Finder sidebar lists in the same directory (FavoriteItems, FavoriteVolumes, TopSidebarSection, iCloudItems, ProjectsItems, NetworkBrowser) are never touched.
- CoreDuet database, Spotlight shortcuts, Siri suggestions: these directories no longer exist on macOS 27; the checks are kept as guarded no-ops and report "not found".
- Launch Services database rebuild (printed as a manual command only)

### Category B — orphan detection is REPORT ONLY

Saved state, containers, group containers, HTTPStorages, WebKit data, Application Support, preferences, Application Scripts, and caches are **listed for review and never deleted**. Orphaned `~/Library/Containers` entries are listed by path and size (they are SIP-protected, so Terminal cannot move them anyway — delete via Finder).

This category previously auto-deleted and destroyed live data for Google Drive, WhatsApp, Zoom, and Apple Shortcuts while all four were installed and running, plus Find My settings (`systemgroup.com.apple.icloud.searchpartyd.sharedsettings.plist`) and the Apple Wallet cache. The cause is structural, not a one-off: deletion was deny-listed, so anything a hand-maintained skip list failed to name was deleted by default.

Matching is now deliberately generous — it protects on any of:
1. Prefix match in either direction after normalization (team ID, `group.`, and `systemgroup.` prefixes stripped)
2. Shared vendor namespace, first two components (`net.whatsapp.family` ← `net.whatsapp.WhatsApp`)
3. A distinctive token (5+ chars) appearing in any installed bundle ID or app name
4. For dot-less names only, a vendor token from an installed app appearing inside it (`ZoomClient3rd` ← `us.zoom.xos`)

Additional guards: anything modified in the last 30 days is never flagged (a live app rewrites its support files constantly, which catches false positives regardless of name matching); anything resolving to a command on `PATH` is never flagged (CLI tools own no `.app` bundle); dot-less preference files are never flagged (app preferences are always named by bundle ID).

Wrongly protecting a real orphan costs one line of output. Wrongly flagging a live app cost real data.
- Orphaned LaunchAgents (background services referencing missing executables) — `launchctl bootout` then trash; the bootout is skipped under `--dry-run`
- Login items referencing deleted apps (reported for manual review)
- Third-party kernel extensions (reported, requires sudo)
- Crash reports and diagnostic logs
- Siri suggestions data

## Command line (`cleanup`)
`bin/cleanup`, symlinked to `~/.local/bin/cleanup`, wraps the same scripts for use outside Claude Code. A cleaning command always dry-runs first, prints per-section totals, the largest items and the report-only list, then asks `Move N item(s) to ~/.Trash? [y/N]`. `-n` stops after the preview, `-y` skips the prompt (the skill uses this), `-v` streams the raw script output. Non-interactive stdin without `-y` stops after the preview and says so. `cleanup all` previews all four modes and asks once. Other subcommands: `history`, `preview`, `log`, `whitelist`, `paths`, `status`.

## History (`/cleanup history [N]`)
Parses `~/.claude/cleanup-operations.log` (and its `.old` rotation) and prints the last N sessions — mode, start/end, item and size totals, counts of trashed / would-trash / skipped / failed / reported — followed by an `mv -n "~/.Trash/<name>.<ts>" "<original path>"` line for every trashed item whose Trash entry still exists. Reversibility is only as good as the Trash: once emptied, nothing here can be restored.

## Borrowed from Mole, and what was deliberately left out

Ported from Mole (`~/.config/mole`): dry-run preview file, per-item operations log with session brackets and rotation, a data-file protection list, tri-state process detection with an unknown-means-running rule, process-table owner matching for caches, `du` with a timeout, whitelist ancestor/descendant semantics, Homebrew `downloads/`-only, the Application Support Chromium-marker rule, partial cargo/gradle cleaning, Xcode DeviceSupport pruning, `CACHEDIR.TAG` detection, `bin`/`vendor` guards, worktree scan roots, and an unconditional cloud-sync exclusion.

Rejected:
- **`mo optimize` as a mode.** DNS flush, Spotlight rebuild (`mdutil -E`), `diskutil resetUserPermissions`, SQLite `VACUUM` on Mail/Messages/Safari, notification and knowledgeC DB pruning are sudo and/or irreversible in place — nothing to move to Trash. The reversible parts (orphan LaunchAgents, login items, quarantine DB) are already in forensic mode. Run `mo optimize` directly when wanted.
- **Tool-native cleaners** (`npm cache clean`, `go clean -modcache`, `uv cache prune`, `pip cache purge`) — they `rm`, bypassing Trash.
- **`.DS_Store` sweeps and `--external` volume cleaning** — pure `rm` of Finder metadata; no Trash equivalent.
- **dev:inode identity rechecks before each removal** — proportionate for `rm -rf`, over-engineered for `mv`.
- **Browser cache deletion**, `~/.cache/huggingface`, `~/.m2`, `~/.cargo/registry/src` — stay report-only.
- **Stale Chrome framework versions** inside the app bundle — editing an app bundle can break its signature.

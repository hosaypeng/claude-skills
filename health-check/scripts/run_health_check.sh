#!/bin/bash
set -e

echo "=== Health Check ==="

# Check LaunchAgents
echo ""
echo "--- LaunchAgents ---"
for plist in "$HOME"/Library/LaunchAgents/com.hsp.*.plist "$HOME"/Library/LaunchAgents/com.hosaypeng.*.plist; do
  [ ! -f "$plist" ] && continue
  name=$(basename "$plist" .plist)
  if launchctl list "$name" &>/dev/null; then
    echo "OK: $name (running)"
  else
    echo "FAIL: $name (not loaded)"
  fi
done

# Check git repos for uncommitted changes
echo ""
echo "--- Git Repos ---"
for repo in "$HOME"/Code/*/; do
  [ ! -d "$repo/.git" ] && continue
  name=$(basename "$repo")
  status=$(cd "$repo" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  unpushed=$(cd "$repo" && git log --oneline @{u}..HEAD 2>/dev/null | wc -l | tr -d ' ')
  if [ "$status" -gt 0 ] || [ "$unpushed" -gt 0 ]; then
    echo "WARN: $name ($status uncommitted, $unpushed unpushed)"
  else
    echo "OK: $name"
  fi
done

# Check vault backup (iCloud sync)
echo ""
echo "--- Vault ---"
VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
if [ -d "$VAULT" ]; then
  note_count=$(find "$VAULT" -name "*.md" -not -path "*/.git/*" 2>/dev/null | wc -l | tr -d ' ')
  echo "OK: Vault accessible ($note_count notes)"
else
  echo "FAIL: Vault not found"
fi

# Check habits pipeline
echo ""
echo "--- Habits Pipeline ---"
HABITS_JSON="$HOME/Code/hosaypeng.github.io/_data/habits.json"
if [ -f "$HABITS_JSON" ]; then
  age=$(( ($(date +%s) - $(stat -f %m "$HABITS_JSON")) / 86400 ))
  if [ "$age" -gt 7 ]; then
    echo "WARN: habits.json is ${age} days old (run /update-habits)"
  else
    echo "OK: habits.json updated ${age} days ago"
  fi
else
  echo "FAIL: habits.json not found"
fi

# Check for dead paths in memory/config files and LaunchAgent plists
echo ""
echo "--- Path Audit ---"
AUDIT_SCRIPT="$HOME/.claude/skills/audit-paths/scripts/audit_paths.sh"
if [ -f "$AUDIT_SCRIPT" ]; then
  dead_output=$(bash "$AUDIT_SCRIPT" all 2>&1 | grep "^DEAD" || true)
  if [ -n "$dead_output" ]; then
    dead_count=$(echo "$dead_output" | wc -l | tr -d ' ')
  else
    dead_count=0
  fi
  if [ "$dead_count" -gt 0 ]; then
    echo "WARN: ${dead_count} dead path(s) found (run /audit-paths for details)"
  else
    echo "OK: All paths valid"
  fi
else
  echo "SKIP: audit-paths skill not found"
fi

# Check recovery repo drift (Brewfile + repos.txt)
echo ""
echo "--- Recovery Repo Drift ---"
RECOVERY="$HOME/Code/macos-recovery-setup"
if [ -d "$RECOVERY" ]; then
  # Brewfile: check for installed formulae/casks not in Brewfile
  # Filter out auto-installed dependencies (only flag explicitly installed packages)
  missing_formulae=$(comm -23 <(brew leaves 2>/dev/null | sort) <(grep '^brew ' "$RECOVERY/Brewfile" 2>/dev/null | sed 's/brew "//;s/"//' | sort))
  missing_casks=$(comm -23 <(brew list --cask 2>/dev/null | sort) <(grep '^cask ' "$RECOVERY/Brewfile" 2>/dev/null | sed 's/cask "//;s/"//' | sort))
  if [ -n "$missing_formulae" ] || [ -n "$missing_casks" ]; then
    count_f=$(echo "$missing_formulae" | grep -c . 2>/dev/null || echo 0)
    count_c=$(echo "$missing_casks" | grep -c . 2>/dev/null || echo 0)
    echo "WARN: Brewfile drift — ${count_f} formula(e), ${count_c} cask(s) installed but not tracked"
    [ -n "$missing_formulae" ] && echo "  formulae: $(echo $missing_formulae | tr '\n' ' ')"
    [ -n "$missing_casks" ] && echo "  casks: $(echo $missing_casks | tr '\n' ' ')"
  else
    echo "OK: Brewfile in sync"
  fi

  # repos.txt: check for repos not in manifest and vice versa
  missing_repos=$(comm -23 <(ls -1d "$HOME"/Code/*/.git 2>/dev/null | xargs -I{} dirname {} | xargs -I{} basename {} | sort) <(grep ' -> ' "$RECOVERY/repos.txt" 2>/dev/null | grep -v '^#' | awk '{print $1}' | sort))
  stale_repos=""
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    [ ! -d "$HOME/Code/$name" ] && stale_repos="$stale_repos $name"
  done < <(grep ' -> ' "$RECOVERY/repos.txt" 2>/dev/null | grep -v '^#' | awk '{print $1}')
  if [ -n "$missing_repos" ] || [ -n "$stale_repos" ]; then
    echo "WARN: repos.txt drift"
    [ -n "$missing_repos" ] && echo "  not tracked: $(echo $missing_repos | tr '\n' ' ')"
    [ -n "$stale_repos" ] && echo "  stale (no longer exist):$stale_repos"
  else
    echo "OK: repos.txt in sync"
  fi
else
  echo "SKIP: Recovery repo not found at $RECOVERY"
fi

# Check for large log files (>100MB)
echo ""
echo "--- Large Log Files ---"
LARGE_LOGS=$(find "$HOME/Code" "$HOME/Jts" "$HOME/.claude" "$HOME/.hermes" "$HOME/.cache" -name "*.log" -size +100M 2>/dev/null)
if [ -n "$LARGE_LOGS" ]; then
  echo "$LARGE_LOGS" | while read -r logfile; do
    size=$(stat -f%z "$logfile" 2>/dev/null || echo 0)
    human=$(echo "$size" | awk '{if ($1>=1073741824) printf "%.1fG",$1/1073741824; else printf "%.0fM",$1/1048576}')
    echo "WARN: $logfile ($human)"
  done
else
  echo "OK: No log files over 100MB"
fi

# Check Claude config sync
echo ""
echo "--- Claude Config Sync ---"
RECOVERY="$HOME/Code/macos-recovery-setup"
if [ -d "$RECOVERY/claude" ]; then
  # Check LaunchAgent is loaded
  if launchctl list "com.hsp.sync-claude-config" &>/dev/null; then
    echo "OK: sync-claude-config agent loaded"
  else
    echo "FAIL: sync-claude-config agent not loaded"
  fi

  # Check settings.json drift
  if [ -f "$RECOVERY/claude/settings.json" ] && [ -f "$HOME/.claude/settings.json" ]; then
    if diff -q "$RECOVERY/claude/settings.json" "$HOME/.claude/settings.json" &>/dev/null; then
      echo "OK: settings.json in sync"
    else
      echo "WARN: settings.json has drifted (recovery repo != live)"
    fi
  fi

  # Check hooks drift (count mismatch)
  live_hooks=$(find "$HOME/.claude/hooks" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
  repo_hooks=$(find "$RECOVERY/claude/hooks" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$live_hooks" -ne "$repo_hooks" ]; then
    echo "WARN: hooks count mismatch (live: $live_hooks, repo: $repo_hooks)"
  else
    echo "OK: hooks in sync ($live_hooks scripts)"
  fi

  # Check commands drift
  live_cmds=$(find "$HOME/.claude/commands" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  repo_cmds=$(find "$RECOVERY/claude/commands" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$live_cmds" -ne "$repo_cmds" ]; then
    echo "WARN: commands count mismatch (live: $live_cmds, repo: $repo_cmds)"
  else
    echo "OK: commands in sync ($live_cmds files)"
  fi
else
  echo "SKIP: No claude/ dir in recovery repo"
fi

echo ""
echo "=== Done ==="

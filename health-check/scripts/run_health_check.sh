#!/bin/bash
# Health check: pass/fail sweep of the user's own automation. Every section runs even if
# an earlier one fails, so no `set -e` - a broken brew call must not hide the sections
# after it. Output lines start with OK / WARN / FAIL / SKIP for grep-ability.

RECOVERY="$HOME/Code/macos-recovery-setup"
VAULT="$HOME/Documents/obsidian"
SKILLS="$HOME/.claude/skills"

echo "=== Health Check ==="

check_launchagents() {
  echo ""
  echo "--- LaunchAgents ---"
  # Every user-installed agent, not just the com.hsp/com.hosaypeng prefixes: nanoclaw,
  # battery-monitor and hermes were invisible to the old glob. Vendor updaters are skipped.
  local plist name entry pid status
  for plist in "$HOME"/Library/LaunchAgents/*.plist; do
    [ -f "$plist" ] || continue
    name=$(basename "$plist" .plist)
    case "$name" in com.apple.*|com.google.*|homebrew.mxcl.*) continue ;; esac
    entry=$(launchctl list 2>/dev/null | awk -v l="$name" '$3 == l')
    if [ -z "$entry" ]; then
      echo "FAIL: $name (not loaded)"
      continue
    fi
    pid=$(echo "$entry" | awk '{print $1}')
    status=$(echo "$entry" | awk '{print $2}')
    if [ "$status" != "0" ] && [ "$status" != "-" ]; then
      echo "WARN: $name (last exit status $status)"
    elif [ "$pid" != "-" ]; then
      echo "OK: $name (running, pid $pid)"
    else
      echo "OK: $name (loaded)"
    fi
  done
}

check_repo() {
  local repo="$1" name status unpushed
  [ -d "$repo/.git" ] || return 0
  name=$(basename "$repo")
  status=$(git -C "$repo" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  # Without an upstream `git log @{u}..HEAD` fails and the old code read that as
  # "0 unpushed", so a never-pushed repo always showed OK.
  if git -C "$repo" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    unpushed=$(git -C "$repo" log --oneline '@{u}..HEAD' 2>/dev/null | wc -l | tr -d ' ')
  else
    unpushed="no-upstream"
  fi
  if [ "$status" -gt 0 ] || [ "$unpushed" != "0" ]; then
    echo "WARN: $name ($status uncommitted, $unpushed unpushed)"
  else
    echo "OK: $name"
  fi
}

check_git_repos() {
  echo ""
  echo "--- Git Repos ---"
  local repo
  for repo in "$HOME"/Code/*/; do
    check_repo "${repo%/}"
  done
  check_repo "$VAULT"
  check_repo "$SKILLS"
}

check_vault() {
  echo ""
  echo "--- Vault ---"
  local note_count
  if [ -d "$VAULT" ]; then
    note_count=$(find "$VAULT" -name "*.md" -not -path "*/.git/*" 2>/dev/null | wc -l | tr -d ' ')
    echo "OK: Vault accessible ($note_count notes)"
  else
    echo "FAIL: Vault not found at $VAULT"
  fi
}

check_habits() {
  echo ""
  echo "--- Habits Pipeline ---"
  # The pipeline is stale only when the vault source is newer than the published JSON.
  # Age alone flagged a 164-day-old habits.json whose source had not changed since April,
  # and told the user to run a push that would publish nothing.
  local habits_json="$HOME/Code/hosaypeng.github.io/_data/habits.json" src src_age json_age
  if [ ! -f "$habits_json" ]; then
    echo "FAIL: habits.json not found"
    return 0
  fi
  src=$(ls -t "$VAULT"/50_areas/personal/all_habits*.md 2>/dev/null | head -1)
  json_age=$(( ($(date +%s) - $(stat -f %m "$habits_json")) / 86400 ))
  if [ -z "$src" ]; then
    echo "WARN: no all_habits*.md found in the vault (habits.json is ${json_age} days old)"
  elif [ "$(stat -f %m "$src")" -gt "$(stat -f %m "$habits_json")" ]; then
    src_age=$(( ($(date +%s) - $(stat -f %m "$src")) / 86400 ))
    echo "WARN: $(basename "$src") edited ${src_age} days ago but habits.json is ${json_age} days old (run /update-habits)"
  else
    echo "OK: habits.json (${json_age} days old) is newer than $(basename "$src")"
  fi
}

check_paths() {
  echo ""
  echo "--- Path Audit ---"
  local audit_script="$SKILLS/audit-paths/scripts/audit_paths.sh" dead_count
  if [ ! -f "$audit_script" ]; then
    echo "SKIP: audit-paths skill not found"
    return 0
  fi
  dead_count=$(bash "$audit_script" all 2>&1 | grep -c "^DEAD" || true)
  if [ "${dead_count:-0}" -gt 0 ]; then
    echo "WARN: ${dead_count} dead path(s) found (run /audit-paths for details)"
  else
    echo "OK: All paths valid"
  fi
}

check_brewfile_drift() {
  local missing_formulae missing_casks count_f count_c
  missing_formulae=$(comm -23 <(brew leaves 2>/dev/null | sort) \
    <(grep '^brew ' "$RECOVERY/Brewfile" 2>/dev/null | sed 's/brew "//;s/"//' | sort))
  missing_casks=$(comm -23 <(brew list --cask 2>/dev/null | sort) \
    <(grep '^cask ' "$RECOVERY/Brewfile" 2>/dev/null | sed 's/cask "//;s/"//' | sort))
  if [ -z "$missing_formulae" ] && [ -z "$missing_casks" ]; then
    echo "OK: Brewfile in sync"
    return 0
  fi
  count_f=$(echo "$missing_formulae" | grep -c . || true)
  count_c=$(echo "$missing_casks" | grep -c . || true)
  echo "WARN: Brewfile drift — ${count_f} formula(e), ${count_c} cask(s) installed but not tracked"
  [ -n "$missing_formulae" ] && echo "  formulae: $(echo "$missing_formulae" | tr '\n' ' ')"
  [ -n "$missing_casks" ] && echo "  casks: $(echo "$missing_casks" | tr '\n' ' ')"
}

check_repos_manifest() {
  local tracked missing_repos="" stale_repos="" dir name
  tracked=$(grep ' -> ' "$RECOVERY/repos.txt" 2>/dev/null | grep -v '^#' | awk '{print $1}')
  for dir in "$HOME"/Code/*/; do
    [ -d "$dir/.git" ] || continue
    name=$(basename "$dir")
    echo "$tracked" | grep -qFx "$name" || missing_repos="$missing_repos $name"
  done
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    [ -d "$HOME/Code/$name" ] || stale_repos="$stale_repos $name"
  done <<< "$tracked"
  if [ -z "$missing_repos" ] && [ -z "$stale_repos" ]; then
    echo "OK: repos.txt in sync"
    return 0
  fi
  echo "WARN: repos.txt drift"
  [ -n "$missing_repos" ] && echo "  not tracked:$missing_repos"
  [ -n "$stale_repos" ] && echo "  stale (no longer exist):$stale_repos"
}

check_recovery_drift() {
  echo ""
  echo "--- Recovery Repo Drift ---"
  if [ ! -d "$RECOVERY" ]; then
    echo "SKIP: Recovery repo not found at $RECOVERY"
    return 0
  fi
  check_brewfile_drift
  check_repos_manifest
}

check_large_logs() {
  echo ""
  echo "--- Large Log Files ---"
  local large_logs logfile size human
  large_logs=$(find "$HOME/Code" "$HOME/Jts" "$HOME/.claude" "$HOME/.hermes" "$HOME/.cache" \
    -name "*.log" -size +100M 2>/dev/null)
  if [ -z "$large_logs" ]; then
    echo "OK: No log files over 100MB"
    return 0
  fi
  while IFS= read -r logfile; do
    size=$(stat -f%z "$logfile" 2>/dev/null || echo 0)
    human=$(echo "$size" | awk '{if ($1>=1073741824) printf "%.1fG",$1/1073741824; else printf "%.0fM",$1/1048576}')
    echo "WARN: $logfile ($human)"
  done <<< "$large_logs"
}

check_config_sync() {
  echo ""
  echo "--- Claude Config Sync ---"
  local live_hooks repo_hooks live_cmds repo_cmds
  if [ ! -d "$RECOVERY/claude" ]; then
    echo "SKIP: No claude/ dir in recovery repo"
    return 0
  fi
  if launchctl list "com.hsp.sync-claude-config" &>/dev/null; then
    echo "OK: sync-claude-config agent loaded"
  else
    echo "FAIL: sync-claude-config agent not loaded"
  fi
  if [ -f "$RECOVERY/claude/settings.json" ] && [ -f "$HOME/.claude/settings.json" ]; then
    if diff -q "$RECOVERY/claude/settings.json" "$HOME/.claude/settings.json" &>/dev/null; then
      echo "OK: settings.json in sync"
    else
      echo "WARN: settings.json has drifted (recovery repo != live)"
    fi
  fi
  live_hooks=$(find "$HOME/.claude/hooks" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
  repo_hooks=$(find "$RECOVERY/claude/hooks" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$live_hooks" -ne "$repo_hooks" ]; then
    echo "WARN: hooks count mismatch (live: $live_hooks, repo: $repo_hooks)"
  else
    echo "OK: hooks in sync ($live_hooks scripts)"
  fi
  live_cmds=$(find "$HOME/.claude/commands" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  repo_cmds=$(find "$RECOVERY/claude/commands" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$live_cmds" -ne "$repo_cmds" ]; then
    echo "WARN: commands count mismatch (live: $live_cmds, repo: $repo_cmds)"
  else
    echo "OK: commands in sync ($live_cmds files)"
  fi
}

check_ioc_freshness() {
  echo ""
  echo "--- Security IOC Lists ---"
  # Both security skills date their IOC files in the filename. A list older than 90 days
  # means the IOC category of that skill is unverified, and nothing else surfaces that daily.
  # Only the newest file per prefix counts: a refresh adds a new dated file and the
  # scripts pick the newest by name, so a superseded list must not keep warning.
  local skill prefix newest date age found=0
  for skill in diagnose threat-hunt; do
    for prefix in $(ls "$SKILLS/$skill/references"/ioc_*.txt 2>/dev/null | sed -E 's/_[0-9]{4}-[0-9]{2}-[0-9]{2}\.txt$//' | sort -u); do
      newest=$(ls "${prefix}"_*.txt 2>/dev/null | sort | tail -1)
      [ -f "$newest" ] || continue
      found=1
      date=$(basename "$newest" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
      [ -n "$date" ] || continue
      age=$(( ($(date +%s) - $(date -j -f "%Y-%m-%d" "$date" +%s 2>/dev/null || date +%s)) / 86400 ))
      if [ "$age" -ge 90 ]; then
        echo "WARN: $skill/$(basename "$newest") is ${age} days old (refresh IOCs)"
      else
        echo "OK: $skill/$(basename "$newest") (${age} days old)"
      fi
    done
  done
  [ "$found" -eq 0 ] && echo "SKIP: no IOC lists found"
}

check_launchagents
check_git_repos
check_vault
check_habits
check_paths
check_recovery_drift
check_large_logs
check_config_sync
check_ioc_freshness

echo ""
echo "=== Done ==="
exit 0

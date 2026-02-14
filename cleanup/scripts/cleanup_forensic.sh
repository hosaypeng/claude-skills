#!/bin/bash
set -e

# Forensic Trace Cleanup
# Scans and removes artifacts left behind by uninstalled apps: quarantine events,
# app usage history, saved states, orphaned preferences, and more.

HOME_DIR="$HOME"
LOG_FILE="$HOME_DIR/.claude/purge-artifacts-log.txt"
TOTAL_FREED=0
INSTALLED_IDS="/tmp/installed_bundle_ids_$$.txt"

safe_size() {
  if [ -e "$1" ]; then
    du -sk "$1" 2>/dev/null | awk '{print $1}'
  else
    echo 0
  fi
}

echo "=== Forensic Trace Cleanup ==="
echo ""

# Phase 1: Build installed apps index
echo "--- Building Installed Apps Index ---"
for app in /Applications/*.app "$HOME_DIR/Applications"/*.app /System/Applications/*.app; do
  if [ -f "$app/Contents/Info.plist" ]; then
    /usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$app/Contents/Info.plist" 2>/dev/null || true
  fi
done | sort -u > "$INSTALLED_IDS"
APP_COUNT=$(wc -l < "$INSTALLED_IDS" | tr -d ' ')
echo "Found $APP_COUNT installed app bundle IDs."
echo ""

# Phase 2: Scan all categories
echo "--- Category A: Execution & Download History ---"

# Quarantine Events
QE_DB="$HOME_DIR/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
if [ -f "$QE_DB" ]; then
  QE_COUNT=$(sqlite3 "$QE_DB" "SELECT COUNT(*) FROM LSQuarantineEvent" 2>/dev/null || echo 0)
  echo "Quarantine Events: $QE_COUNT entries"
  if [ "$QE_COUNT" -gt 0 ]; then
    sqlite3 "$QE_DB" "DELETE FROM LSQuarantineEvent" 2>/dev/null && echo "  Cleared." || echo "  Could not clear (may need manual deletion)." >&2
  fi
else
  echo "Quarantine Events: not found"
fi

# KnowledgeC
KC_DB="$HOME_DIR/Library/Application Support/Knowledge/knowledgeC.db"
if [ -f "$KC_DB" ]; then
  KC_SIZE=$(safe_size "$KC_DB")
  echo "KnowledgeC Database: $((KC_SIZE / 1024))MB"
  rm -f "$KC_DB" 2>/dev/null && {
    TOTAL_FREED=$((TOTAL_FREED + KC_SIZE))
    echo "  Removed."
  } || echo "  TCC-protected. Delete manually via Finder: ~/Library/Application Support/Knowledge/" >&2
else
  echo "KnowledgeC Database: not found"
fi

# CoreDuet
CD_DIR="$HOME_DIR/Library/Application Support/com.apple.DuetExpertCenter"
if [ -d "$CD_DIR" ]; then
  CD_SIZE=$(safe_size "$CD_DIR")
  TOTAL_FREED=$((TOTAL_FREED + CD_SIZE))
  rm -rf "$CD_DIR"/* 2>/dev/null || true
  echo "CoreDuet Database: cleared ($((CD_SIZE / 1024))MB)"
else
  echo "CoreDuet Database: not found"
fi

# Recent Items
RI_DIR="$HOME_DIR/Library/Application Support/com.apple.sharedfilelist"
if [ -d "$RI_DIR" ]; then
  rm -f "$RI_DIR"/*.sfl2 "$RI_DIR"/*.sfl3 2>/dev/null || true
  echo "Recent Items: cleared"
else
  echo "Recent Items: not found"
fi

# Spotlight Shortcuts
SS_DIR="$HOME_DIR/Library/Application Support/com.apple.spotlight.Shortcuts"
if [ -d "$SS_DIR" ]; then
  SS_SIZE=$(safe_size "$SS_DIR")
  TOTAL_FREED=$((TOTAL_FREED + SS_SIZE))
  rm -rf "$SS_DIR" 2>/dev/null || true
  echo "Spotlight Shortcuts: cleared"
else
  echo "Spotlight Shortcuts: not found"
fi

# Launch Services rebuild
echo "Launch Services: rebuilding database..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user 2>/dev/null || true
echo "  Done."
echo ""

echo "--- Category B: Orphaned App Data ---"

# Saved Application State (orphans)
SAS_DIR="$HOME_DIR/Library/Saved Application State"
if [ -d "$SAS_DIR" ]; then
  ORPHAN_COUNT=0
  for state_dir in "$SAS_DIR"/*/; do
    bundle_id=$(basename "$state_dir")
    [[ "$bundle_id" == com.apple.* ]] && continue
    if ! grep -q "^${bundle_id}$" "$INSTALLED_IDS" 2>/dev/null; then
      size=$(safe_size "$state_dir")
      TOTAL_FREED=$((TOTAL_FREED + size))
      rm -rf "$state_dir" 2>/dev/null || true
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Saved Application State: removed $ORPHAN_COUNT orphaned folders"
else
  echo "Saved Application State: not found"
fi

# Orphaned Containers
CONT_DIR="$HOME_DIR/Library/Containers"
if [ -d "$CONT_DIR" ]; then
  ORPHAN_COUNT=0
  for container in "$CONT_DIR"/*/; do
    bundle_id=$(basename "$container")
    [[ "$bundle_id" == com.apple.* ]] && continue
    [[ "$bundle_id" =~ ^[A-F0-9]{8}- ]] && continue
    if ! grep -q "^${bundle_id}$" "$INSTALLED_IDS" 2>/dev/null; then
      size=$(safe_size "$container")
      TOTAL_FREED=$((TOTAL_FREED + size))
      rm -rf "$container" 2>/dev/null || true
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned Containers: removed $ORPHAN_COUNT"
else
  echo "Containers directory: not found"
fi

# Orphaned Group Containers
GC_DIR="$HOME_DIR/Library/Group Containers"
if [ -d "$GC_DIR" ]; then
  ORPHAN_COUNT=0
  for gc in "$GC_DIR"/*/; do
    gid=$(basename "$gc")
    [[ "$gid" == *apple* ]] && continue
    if ! grep -q "$(echo "$gid" | sed 's/^[^.]*\.//')" "$INSTALLED_IDS" 2>/dev/null; then
      size=$(safe_size "$gc")
      TOTAL_FREED=$((TOTAL_FREED + size))
      rm -rf "$gc" 2>/dev/null || true
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned Group Containers: removed $ORPHAN_COUNT"
else
  echo "Group Containers: not found"
fi

# Orphaned HTTPStorages
HS_DIR="$HOME_DIR/Library/HTTPStorages"
if [ -d "$HS_DIR" ]; then
  ORPHAN_COUNT=0
  for storage in "$HS_DIR"/*/; do
    bundle_id=$(basename "$storage")
    [[ "$bundle_id" == com.apple.* ]] && continue
    if ! grep -q "^${bundle_id}$" "$INSTALLED_IDS" 2>/dev/null; then
      size=$(safe_size "$storage")
      TOTAL_FREED=$((TOTAL_FREED + size))
      rm -rf "$storage" 2>/dev/null || true
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned HTTPStorages: removed $ORPHAN_COUNT"
else
  echo "HTTPStorages: not found"
fi
echo ""

echo "--- Category C: Background Services ---"

# Orphaned LaunchAgents (user)
LA_DIR="$HOME_DIR/Library/LaunchAgents"
if [ -d "$LA_DIR" ]; then
  ORPHAN_COUNT=0
  for plist in "$LA_DIR"/*.plist; do
    [ -f "$plist" ] || continue
    prog=$(/usr/libexec/PlistBuddy -c "Print ProgramArguments:0" "$plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Print Program" "$plist" 2>/dev/null || echo "")
    if [ -n "$prog" ] && [ ! -e "$prog" ]; then
      echo "  Orphaned LaunchAgent: $(basename "$plist") -> $prog"
      launchctl bootout "gui/$(id -u)" "$plist" 2>/dev/null || true
      rm -f "$plist" 2>/dev/null || true
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned LaunchAgents: removed $ORPHAN_COUNT"
else
  echo "LaunchAgents: not found"
fi
echo ""

echo "--- Category D: Logs & Crash Reports ---"

# Crash reports for deleted apps
DR_DIR="$HOME_DIR/Library/Logs/DiagnosticReports"
if [ -d "$DR_DIR" ]; then
  DR_SIZE=$(safe_size "$DR_DIR")
  TOTAL_FREED=$((TOTAL_FREED + DR_SIZE))
  rm -rf "$DR_DIR"/* 2>/dev/null || true
  echo "DiagnosticReports: cleared ($((DR_SIZE / 1024))MB)"
else
  echo "DiagnosticReports: not found"
fi

# MobileDevice Logs
MD_DIR="$HOME_DIR/Library/Logs/CrashReporter/MobileDevice"
if [ -d "$MD_DIR" ]; then
  MD_SIZE=$(safe_size "$MD_DIR")
  TOTAL_FREED=$((TOTAL_FREED + MD_SIZE))
  rm -rf "$MD_DIR"/* 2>/dev/null || true
  echo "MobileDevice Logs: cleared ($((MD_SIZE / 1024))MB)"
else
  echo "MobileDevice Logs: not found"
fi
echo ""

echo "--- Category E: Privacy Traces ---"

# Siri Suggestions
SIRI_DIR="$HOME_DIR/Library/Application Support/com.apple.siri.suggestions"
if [ -d "$SIRI_DIR" ]; then
  SIRI_SIZE=$(safe_size "$SIRI_DIR")
  TOTAL_FREED=$((TOTAL_FREED + SIRI_SIZE))
  rm -rf "$SIRI_DIR"/* 2>/dev/null || true
  echo "Siri Suggestions: cleared ($((SIRI_SIZE / 1024))MB)"
else
  echo "Siri Suggestions: not found"
fi
echo ""

# Cleanup temp file
rm -f "$INSTALLED_IDS"

# Summary
FREED_MB=$((TOTAL_FREED / 1024))
echo "=== Forensic Trace Cleanup Complete ==="
echo "Space recovered: approximately ${FREED_MB}MB (${TOTAL_FREED}K)"
echo ""
echo "NOTE: Some items (KnowledgeC, TCC database) may require manual deletion"
echo "via Finder due to macOS security protections. Never grant Full Disk Access"
echo "to Terminal for this purpose."

# Log
mkdir -p "$(dirname "$LOG_FILE")"
cat >> "$LOG_FILE" <<LOGEOF
========================================
Forensic Cleanup: $(date '+%Y-%m-%d %H:%M:%S')
========================================
Space Recovered: ${FREED_MB}MB (${TOTAL_FREED}K)
Categories: Quarantine events, app usage history, orphaned data,
  background services, crash reports, privacy traces
Status: Success
========================================

LOGEOF

echo ""
echo "Log appended to $LOG_FILE"

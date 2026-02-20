#!/bin/bash
set -e

# Forensic Trace Cleanup
# Scans and removes artifacts left behind by uninstalled apps: quarantine events,
# app usage history, saved states, orphaned preferences, and more.

source "$(dirname "$0")/_helpers.sh"

HOME_DIR="$HOME"
LOG_FILE="$HOME_DIR/.claude/purge-artifacts-log.txt"
INSTALLED_IDS="/tmp/installed_bundle_ids_$$.txt"

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

# === Category A: Execution & Download History ===
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
  echo "KnowledgeC Database: $(format_size $KC_SIZE)"
  safe_trash "$KC_DB" 2>/dev/null || echo "  TCC-protected. Delete manually via Finder: ~/Library/Application Support/Knowledge/" >&2
else
  echo "KnowledgeC Database: not found"
fi

# CoreDuet
CD_DIR="$HOME_DIR/Library/Application Support/com.apple.DuetExpertCenter"
if [ -d "$CD_DIR" ]; then
  CD_SIZE=$(safe_size "$CD_DIR")
  safe_trash_contents "$CD_DIR"
  echo "CoreDuet Database: cleared ($(format_size $CD_SIZE))"
else
  echo "CoreDuet Database: not found"
fi

# Recent Items
RI_DIR="$HOME_DIR/Library/Application Support/com.apple.sharedfilelist"
if [ -d "$RI_DIR" ]; then
  for f in "$RI_DIR"/*.sfl2 "$RI_DIR"/*.sfl3; do
    [ -f "$f" ] && safe_trash "$f"
  done
  echo "Recent Items: cleared"
else
  echo "Recent Items: not found"
fi

# Spotlight Shortcuts
SS_DIR="$HOME_DIR/Library/Application Support/com.apple.spotlight.Shortcuts"
if [ -d "$SS_DIR" ]; then
  safe_trash "$SS_DIR"
  echo "Spotlight Shortcuts: cleared"
else
  echo "Spotlight Shortcuts: not found"
fi

# Launch Services rebuild
echo "Launch Services: rebuilding database..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user 2>/dev/null || true
echo "  Done."
echo ""

# === Category B: Orphaned App Data ===
echo "--- Category B: Orphaned App Data ---"

# Saved Application State (orphans)
SAS_DIR="$HOME_DIR/Library/Saved Application State"
if [ -d "$SAS_DIR" ]; then
  ORPHAN_COUNT=0
  for state_dir in "$SAS_DIR"/*/; do
    [ -d "$state_dir" ] || continue
    bundle_id=$(basename "$state_dir")
    [[ "$bundle_id" == com.apple.* ]] && continue
    if ! grep -q "^${bundle_id}$" "$INSTALLED_IDS" 2>/dev/null; then
      safe_trash "$state_dir"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Saved Application State: removed $ORPHAN_COUNT orphaned folders"
else
  echo "Saved Application State: not found"
fi

# Orphaned Containers (report only — SIP-protected, cannot be moved by Terminal)
CONT_DIR="$HOME_DIR/Library/Containers"
if [ -d "$CONT_DIR" ]; then
  ORPHAN_COUNT=0
  for container in "$CONT_DIR"/*/; do
    [ -d "$container" ] || continue
    bundle_id=$(basename "$container")
    [[ "$bundle_id" == com.apple.* ]] && continue
    [[ "$bundle_id" =~ ^[A-F0-9]{8}- ]] && continue
    if ! grep -q "^${bundle_id}$" "$INSTALLED_IDS" 2>/dev/null; then
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  if [ "$ORPHAN_COUNT" -gt 0 ]; then
    echo "Orphaned Containers: $ORPHAN_COUNT found (SIP-protected — delete via Finder if needed)"
  else
    echo "Orphaned Containers: none"
  fi
else
  echo "Containers directory: not found"
fi

# Orphaned Group Containers
GC_DIR="$HOME_DIR/Library/Group Containers"
if [ -d "$GC_DIR" ]; then
  ORPHAN_COUNT=0
  for gc in "$GC_DIR"/*/; do
    [ -d "$gc" ] || continue
    gid=$(basename "$gc")
    [[ "$gid" == *apple* ]] && continue
    # Strip team ID or "group" prefix to get approximate bundle ID
    extracted=$(echo "$gid" | sed 's/^[^.]*\.//')
    # Check if any installed bundle ID is a prefix of the extracted name
    # e.g. "net.whatsapp.WhatsApp" should match "net.whatsapp.WhatsApp.shared"
    match_found=false
    while IFS= read -r bid; do
      [ -z "$bid" ] && continue
      if [ "${extracted#$bid}" != "$extracted" ]; then
        match_found=true
        break
      fi
    done < "$INSTALLED_IDS"
    if [ "$match_found" = false ]; then
      safe_trash "$gc"
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
    [ -d "$storage" ] || continue
    bundle_id=$(basename "$storage")
    [[ "$bundle_id" == com.apple.* ]] && continue
    if ! grep -q "^${bundle_id}$" "$INSTALLED_IDS" 2>/dev/null; then
      safe_trash "$storage"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned HTTPStorages: removed $ORPHAN_COUNT"
else
  echo "HTTPStorages: not found"
fi

# Orphaned Application Support directories
AS_DIR="$HOME_DIR/Library/Application Support"
if [ -d "$AS_DIR" ]; then
  ORPHAN_COUNT=0
  for support_dir in "$AS_DIR"/*/; do
    [ -d "$support_dir" ] || continue
    dir_name=$(basename "$support_dir")
    # Skip Apple and system directories
    [[ "$dir_name" == com.apple.* ]] && continue
    [[ "$dir_name" == Apple ]] && continue
    [[ "$dir_name" == Knowledge ]] && continue
    [[ "$dir_name" == CrashReporter ]] && continue
    # Check if it looks like a bundle ID and is orphaned
    if [[ "$dir_name" == *.*.* ]] && ! grep -q "^${dir_name}$" "$INSTALLED_IDS" 2>/dev/null; then
      size=$(safe_size "$support_dir")
      echo "  Orphaned: $dir_name ($(format_size $size))"
      safe_trash "$support_dir"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned Application Support: removed $ORPHAN_COUNT"
else
  echo "Application Support: not found"
fi

# Orphaned Preferences (plist files)
echo ""
echo "--- Category B2: Orphaned Preferences ---"
PREF_DIR="$HOME_DIR/Library/Preferences"
if [ -d "$PREF_DIR" ]; then
  ORPHAN_COUNT=0
  for plist in "$PREF_DIR"/*.plist; do
    [ -f "$plist" ] || continue
    plist_name=$(basename "$plist" .plist)
    # Skip Apple plists
    [[ "$plist_name" == com.apple.* ]] && continue
    [[ "$plist_name" == Apple* ]] && continue
    # Skip system/known plists
    [[ "$plist_name" == loginwindow ]] && continue
    [[ "$plist_name" == ByHost ]] && continue
    # Check if bundle ID matches an installed app
    if ! grep -q "^${plist_name}$" "$INSTALLED_IDS" 2>/dev/null; then
      # Only flag it, don't auto-delete plists (some belong to CLI tools, not .app bundles)
      echo "  Possibly orphaned: $plist_name"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Possibly orphaned preferences: $ORPHAN_COUNT (review manually — some belong to CLI tools)"
else
  echo "Preferences: not found"
fi
echo ""

# === Category C: Background Services ===
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
      safe_trash "$plist"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned LaunchAgents: removed $ORPHAN_COUNT"
else
  echo "LaunchAgents: not found"
fi

# Login Items referencing deleted apps
echo ""
echo "Checking login items..."
LOGIN_ITEMS=$(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null || true)
if [ -n "$LOGIN_ITEMS" ]; then
  echo "  Current login items: $LOGIN_ITEMS"
  echo "  (Review manually — remove items for uninstalled apps via System Settings > Login Items)"
fi

# Orphaned kernel extensions (report only)
echo ""
echo "Checking kernel extensions..."
if [ -d "/Library/Extensions" ]; then
  KEXT_COUNT=0
  for kext in /Library/Extensions/*.kext; do
    [ -d "$kext" ] || continue
    echo "  Found: $(basename "$kext") (report only — requires sudo to remove)"
    KEXT_COUNT=$((KEXT_COUNT + 1))
  done
  [ "$KEXT_COUNT" -eq 0 ] && echo "  No third-party kernel extensions."
fi
echo ""

# === Category D: Logs & Crash Reports ===
echo "--- Category D: Logs & Crash Reports ---"

# Crash reports
DR_DIR="$HOME_DIR/Library/Logs/DiagnosticReports"
if [ -d "$DR_DIR" ]; then
  DR_SIZE=$(safe_size "$DR_DIR")
  safe_trash_contents "$DR_DIR"
  echo "DiagnosticReports: cleared ($(format_size $DR_SIZE))"
else
  echo "DiagnosticReports: not found"
fi

# MobileDevice Logs
MD_DIR="$HOME_DIR/Library/Logs/CrashReporter/MobileDevice"
if [ -d "$MD_DIR" ]; then
  MD_SIZE=$(safe_size "$MD_DIR")
  safe_trash_contents "$MD_DIR"
  echo "MobileDevice Logs: cleared ($(format_size $MD_SIZE))"
else
  echo "MobileDevice Logs: not found"
fi
echo ""

# === Category E: Privacy Traces ===
echo "--- Category E: Privacy Traces ---"

# Siri Suggestions
SIRI_DIR="$HOME_DIR/Library/Application Support/com.apple.siri.suggestions"
if [ -d "$SIRI_DIR" ]; then
  SIRI_SIZE=$(safe_size "$SIRI_DIR")
  safe_trash_contents "$SIRI_DIR"
  echo "Siri Suggestions: cleared ($(format_size $SIRI_SIZE))"
else
  echo "Siri Suggestions: not found"
fi
echo ""

# Cleanup temp file
rm -f "$INSTALLED_IDS"

# Summary
FREED_MB=$((TOTAL_FREED / 1024))
echo "=== Forensic Trace Cleanup Complete ==="
echo "Space recovered: approximately $(format_size $TOTAL_FREED)"
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
Space Recovered: $(format_size $TOTAL_FREED)
Categories: Quarantine events, app usage history, orphaned data,
  background services, crash reports, privacy traces
Status: Success
========================================

LOGEOF

echo ""
echo "Log appended to $LOG_FILE"

#!/bin/bash
set -e

# Forensic Trace Cleanup
# Scans and removes artifacts left behind by uninstalled apps: quarantine events,
# app usage history, saved states, orphaned preferences, and more.

source "$(dirname "$0")/_helpers.sh"

HOME_DIR="$HOME"
LOG_FILE="$HOME_DIR/.claude/purge-artifacts-log.txt"
INSTALLED_IDS=$(mktemp)

echo "=== Forensic Trace Cleanup ==="
echo ""

# Phase 1: Build installed apps index
echo "--- Building Installed Apps Index ---"
INSTALLED_NAMES=$(mktemp)
trap 'rm -f "$INSTALLED_IDS" "$INSTALLED_NAMES"' EXIT
for app in /Applications/*.app "$HOME_DIR/Applications"/*.app /System/Applications/*.app; do
  if [ -f "$app/Contents/Info.plist" ]; then
    /usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$app/Contents/Info.plist" 2>/dev/null || true
  fi
  # Also capture the .app folder name (lowercased) for name-based matching
  basename "$app" .app 2>/dev/null | tr '[:upper:]' '[:lower:]'
done | sort -u > "$INSTALLED_IDS"
# Separate file for app display names (lowercased)
for app in /Applications/*.app "$HOME_DIR/Applications"/*.app /System/Applications/*.app; do
  basename "$app" .app 2>/dev/null | tr '[:upper:]' '[:lower:]'
done | sort -u > "$INSTALLED_NAMES"
APP_COUNT=$(grep -c '\.' "$INSTALLED_IDS" | tr -d ' ')
echo "Found $APP_COUNT installed app bundle IDs."
echo ""

# === Category A: Execution & Download History ===
echo "--- Category A: Execution & Download History ---"

# Quarantine Events (report only — clearing weakens Gatekeeper security)
QE_DB="$HOME_DIR/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
if [ -f "$QE_DB" ]; then
  QE_COUNT=$(sqlite3 "$QE_DB" "SELECT COUNT(*) FROM LSQuarantineEvent" 2>/dev/null || echo 0)
  echo "Quarantine Events: $QE_COUNT entries (report only — clearing removes Gatekeeper download history)"
else
  echo "Quarantine Events: not found"
fi

# KnowledgeC (report only — contains Screen Time and parental control data)
KC_DB="$HOME_DIR/Library/Application Support/Knowledge/knowledgeC.db"
if [ -f "$KC_DB" ]; then
  KC_SIZE=$(safe_size "$KC_DB")
  echo "KnowledgeC Database: $(format_size $KC_SIZE) (report only — contains Screen Time data)"
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

# Launch Services (report only — rebuild resets file associations and can disrupt Finder)
echo "Launch Services: run manually if needed:"
echo "  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user"
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
    if ! grep -Fxq "$bundle_id" "$INSTALLED_IDS" 2>/dev/null; then
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
    if ! grep -Fxq "$bundle_id" "$INSTALLED_IDS" 2>/dev/null; then
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

# Orphaned HTTPStorages (files and directories)
HS_DIR="$HOME_DIR/Library/HTTPStorages"
if [ -d "$HS_DIR" ]; then
  ORPHAN_COUNT=0
  for storage in "$HS_DIR"/*; do
    [ -e "$storage" ] || continue
    storage_name=$(basename "$storage")
    [[ "$storage_name" == com.apple.* ]] && continue
    # Strip .binarycookies suffix for matching
    match_name="${storage_name%.binarycookies}"
    # Skip system entries
    case "$match_name" in
      askpermissiond|crashpad-handler|familycircled) continue ;;
    esac
    # Check if bundle ID matches an installed app (prefix match)
    match_found=false
    while IFS= read -r bid; do
      [ -z "$bid" ] && continue
      if [[ "$match_name" == "$bid"* ]]; then
        match_found=true
        break
      fi
    done < "$INSTALLED_IDS"
    if [ "$match_found" = false ]; then
      safe_trash "$storage"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned HTTPStorages: removed $ORPHAN_COUNT"
else
  echo "HTTPStorages: not found"
fi

# Orphaned WebKit data
WK_DIR="$HOME_DIR/Library/WebKit"
if [ -d "$WK_DIR" ]; then
  ORPHAN_COUNT=0
  for wk_entry in "$WK_DIR"/*/; do
    [ -d "$wk_entry" ] || continue
    bundle_id=$(basename "$wk_entry")
    [[ "$bundle_id" == com.apple.* ]] && continue
    if ! grep -Fxq "$bundle_id" "$INSTALLED_IDS" 2>/dev/null; then
      safe_trash "$wk_entry"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned WebKit data: removed $ORPHAN_COUNT"
else
  echo "WebKit data: not found"
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
    # Match by bundle ID (com.foo.bar style)
    if [[ "$dir_name" == *.*.* ]] && ! grep -Fxq "$dir_name" "$INSTALLED_IDS" 2>/dev/null; then
      size=$(safe_size "$support_dir")
      echo "  Orphaned: $dir_name ($(format_size $size))"
      safe_trash "$support_dir"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
      continue
    fi
    # Match non-bundle-ID dirs by checking if any installed bundle ID
    # contains the dir name as a component (e.g. "Discord" matches "com.hnc.Discord")
    if [[ "$dir_name" != *.*.* ]]; then
      dir_lower=$(echo "$dir_name" | tr '[:upper:]' '[:lower:]' | tr -d ' -')
      # Skip known system/framework directories that are not apps
      case "$dir_lower" in
        apple|knowledge|crashreporter|google|homebrew|caches|cloudkit|\
        configurationprofiles|diskimages|icloud|icdd|\
        syncservices|networkserviceproxy|videosubscriptionsd|segment|\
        animoji|sesstorage|googleheartbeatstorage|\
        addressbook|calltransactions|callhistorydb|callhistorytransactions|\
        clouddocs|contactsd|controlcenter|differentialprivacy|\
        facetime|fileprovider|homeenergyd|icloudmailagent|\
        identityservicesd|locationaccessstored|mobilesync|music|\
        privatecloudcomputed|spotlight|stickersd|tipsd) continue ;;
      esac
      # Check if any installed bundle ID contains this name as a component
      match_found=false
      while IFS= read -r bid; do
        [ -z "$bid" ] && continue
        bid_lower=$(echo "$bid" | tr '[:upper:]' '[:lower:]')
        # Check each dot-separated component of the bundle ID
        IFS='.' read -ra parts <<< "$bid_lower"
        for part in "${parts[@]}"; do
          part_clean=$(echo "$part" | tr -d ' -')
          if [[ "$dir_lower" == *"$part_clean"* ]] || [[ "$part_clean" == *"$dir_lower"* ]]; then
            match_found=true
            break 2
          fi
        done
      done < "$INSTALLED_IDS"
      # Also check against installed app display names
      while IFS= read -r app_name; do
        [ -z "$app_name" ] && continue
        app_clean=$(echo "$app_name" | tr -d ' -')
        if [[ "$dir_lower" == "$app_clean" ]] || [[ "$app_clean" == "$dir_lower" ]]; then
          match_found=true
          break
        fi
      done < "$INSTALLED_NAMES"
      if [ "$match_found" = false ]; then
        size=$(safe_size "$support_dir")
        if [ "$size" -gt 0 ]; then
          echo "  Orphaned (by name): $dir_name ($(format_size $size))"
          safe_trash "$support_dir"
          ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
        fi
      fi
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
  # Known system/framework plists that are not app bundle IDs
  KNOWN_SYSTEM_PLISTS="loginwindow ByHost pbs sharedfilelistd corespotlightd diagnostics_agent mbuseragent icloudmailagent familycircled ContextStoreAgent ScopedBookmarkAgent MobileMeAccounts MiniLauncher SKGActivityJournal interpreter com.firebase.FIRInstallations com.claude.usagebar ChatGPTHelper cfx"
  for plist in "$PREF_DIR"/*.plist; do
    [ -f "$plist" ] || continue
    plist_name=$(basename "$plist" .plist)
    # Skip Apple plists
    [[ "$plist_name" == com.apple.* ]] && continue
    [[ "$plist_name" == Apple* ]] && continue
    # Skip known system/framework plists
    skip=false
    for known in $KNOWN_SYSTEM_PLISTS; do
      if [[ "$plist_name" == "$known"* ]]; then
        skip=true
        break
      fi
    done
    [ "$skip" = true ] && continue
    # Skip Segment analytics plists (com.segment.storage.*)
    [[ "$plist_name" == com.segment.* ]] && continue
    # Skip LaunchDarkly feature flag plists
    [[ "$plist_name" == com.launchdarkly.* ]] && continue
    # Skip generic/ambiguous plists
    [[ "$plist_name" == "Avatar Cache Index" ]] && continue
    # Check if bundle ID matches an installed app (prefix match)
    match_found=false
    while IFS= read -r bid; do
      [ -z "$bid" ] && continue
      if [[ "$plist_name" == "$bid"* ]]; then
        match_found=true
        break
      fi
    done < "$INSTALLED_IDS"
    if [ "$match_found" = false ]; then
      safe_trash "$plist"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned preferences: removed $ORPHAN_COUNT"
else
  echo "Preferences: not found"
fi
echo ""

# Orphaned Application Scripts
echo "--- Category B3: Orphaned Application Scripts ---"
ASCRIPT_DIR="$HOME_DIR/Library/Application Scripts"
if [ -d "$ASCRIPT_DIR" ]; then
  ORPHAN_COUNT=0
  for script_dir in "$ASCRIPT_DIR"/*/; do
    [ -d "$script_dir" ] || continue
    dir_name=$(basename "$script_dir")
    [[ "$dir_name" == com.apple.* ]] && continue
    # Skip UUID-named dirs (system-managed)
    [[ "$dir_name" =~ ^[A-F0-9]{8}- ]] && continue
    # Skip Shortcuts (group.is.workflow)
    [[ "$dir_name" == group.is.workflow* ]] && continue
    [[ "$dir_name" == *apple* ]] && continue
    # Extract meaningful bundle ID: strip team ID prefix
    # e.g. "UBF8T346G9.com.microsoft.Office" -> "com.microsoft.Office"
    extracted="$dir_name"
    if [[ "$dir_name" =~ ^[A-Z0-9]+\..+ ]]; then
      extracted=$(echo "$dir_name" | sed 's/^[A-Z0-9]*\.//')
    fi
    # Handle "group.com.foo" -> "com.foo"
    if [[ "$extracted" == group.* ]]; then
      extracted=$(echo "$extracted" | sed 's/^group\.//')
    fi
    # Check if any installed bundle ID is a prefix of the extracted name (or vice versa)
    match_found=false
    while IFS= read -r bid; do
      [ -z "$bid" ] && continue
      if [[ "$extracted" == "$bid"* ]] || [[ "$bid" == "$extracted"* ]]; then
        match_found=true
        break
      fi
    done < "$INSTALLED_IDS"
    if [ "$match_found" = false ]; then
      safe_trash "$script_dir"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned Application Scripts: removed $ORPHAN_COUNT"
else
  echo "Application Scripts: not found"
fi
echo ""

# Orphaned Caches (cross-reference against installed apps)
echo "--- Category B4: Orphaned Caches ---"
OCACHE_DIR="$HOME_DIR/Library/Caches"
if [ -d "$OCACHE_DIR" ]; then
  ORPHAN_COUNT=0
  for cache_entry in "$OCACHE_DIR"/*/; do
    [ -d "$cache_entry" ] || continue
    cache_name=$(basename "$cache_entry")
    # Skip Apple caches
    [[ "$cache_name" == com.apple.* ]] && continue
    # Skip system/framework caches
    case "$cache_name" in
      CloudKit|FamilyCircle|GeoServices|claude-cli-nodejs) continue ;;
    esac
    # Check if bundle ID matches an installed app (prefix match for .ShipIt etc.)
    match_found=false
    while IFS= read -r bid; do
      [ -z "$bid" ] && continue
      if [[ "$cache_name" == "$bid"* ]]; then
        match_found=true
        break
      fi
    done < "$INSTALLED_IDS"
    if [ "$match_found" = false ]; then
      size=$(safe_size "$cache_entry")
      safe_trash "$cache_entry"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned Caches: removed $ORPHAN_COUNT"
else
  echo "Caches: not found"
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
  preferences, application scripts, caches, background services,
  crash reports, privacy traces
Status: Success
========================================

LOGEOF

echo ""
echo "Log appended to $LOG_FILE"

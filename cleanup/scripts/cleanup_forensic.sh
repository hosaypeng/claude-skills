#!/bin/bash
set -e

# Forensic Trace Cleanup
# Scans and removes artifacts left behind by uninstalled apps: quarantine events,
# app usage history, saved states, orphaned preferences, and more.

export CLEANUP_MODE=forensic
source "$(dirname "$0")/_helpers.sh"

HOME_DIR="$HOME"
INSTALLED_IDS=$(mktemp)

echo "=== Forensic Trace Cleanup ==="
echo ""
start_run

# Phase 1: Build installed apps index
section "Building Installed Apps Index"
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

# Strip team-ID, group, and systemgroup prefixes so a container ID can be
# compared against a real bundle ID. Without this,
# "EQHXZ8M8AV.group.com.google.drivefs" never matches "com.google.drivefs".
normalize_bundle_id() {
  local id="$1"
  id=$(echo "$id" | sed -E 's/^[A-Z0-9]{10}\.//')
  id="${id#systemgroup.}"
  id="${id#group.}"
  echo "$id"
}

# True if an ID belongs to Apple, in any of the shapes Apple actually uses:
# com.apple.*, group.com.apple.*, systemgroup.com.apple.*, group.is.workflow.*
# (Shortcuts), and bare framework names like PassKit.
is_apple_id() {
  local id="$1"
  case "$id" in
    com.apple.*|*.com.apple.*|systemgroup.*|group.com.apple.*|*apple*) return 0 ;;
    group.is.workflow*|is.workflow*) return 0 ;;
    PassKit|CloudKit|GeoServices|FamilyCircle|Knowledge|CrashReporter) return 0 ;;
  esac
  return 1
}

# True if any installed app plausibly owns the given (normalized) ID.
# Deliberately generous: this gates a report, so wrongly protecting a real
# orphan costs a line of output, while wrongly flagging a live app is what
# destroyed Google Drive and Zoom data. Three widening passes:
#   1. prefix match either direction  (com.google.drivefs)
#   2. vendor namespace, first two components  (net.whatsapp.family -> net.whatsapp.WhatsApp)
#   3. distinctive token appearing in a bundle ID or app name  (ZoomClient3rd -> us.zoom.xos)
matches_installed_app() {
  local candidate="$1"
  [ -z "$candidate" ] && return 0
  local cand_lower
  cand_lower=$(echo "$candidate" | tr '[:upper:]' '[:lower:]')
  local cand_vendor
  cand_vendor=$(echo "$cand_lower" | cut -d. -f1-2)

  local bid bid_lower bid_vendor
  while IFS= read -r bid; do
    [ -z "$bid" ] && continue
    bid_lower=$(echo "$bid" | tr '[:upper:]' '[:lower:]')
    [[ "$cand_lower" == "$bid_lower"* ]] && return 0
    [[ "$bid_lower" == "$cand_lower"* ]] && return 0
    if [[ "$cand_lower" == *.* ]] && [[ "$bid_lower" == *.* ]]; then
      bid_vendor=$(echo "$bid_lower" | cut -d. -f1-2)
      [ "$cand_vendor" = "$bid_vendor" ] && return 0
    fi
  done < "$INSTALLED_IDS"

  # Token pass: split the candidate on dots and test each distinctive token
  # against every installed bundle ID and app display name.
  local token
  for token in $(echo "$cand_lower" | tr '.' ' '); do
    [ "${#token}" -lt 5 ] && continue
    case "$token" in
      group|apps|desktop|client|helper|shared|private|family|service|updater) continue ;;
    esac
    grep -qi -- "$token" "$INSTALLED_IDS" 2>/dev/null && return 0
    grep -qi -- "$token" "$INSTALLED_NAMES" 2>/dev/null && return 0
  done

  # Reverse pass: a vendor-named container carries no bundle ID at all
  # ("ZoomClient3rd"), so test whether a vendor token from any installed app
  # sits inside it. Restricted to dot-less candidates — anything shaped like a
  # bundle ID was already judged by the prefix and vendor passes above, and
  # substring-matching those over-protects real orphans.
  [[ "$cand_lower" == *.* ]] && return 1
  local vendor_token
  for vendor_token in $(cat "$INSTALLED_IDS" "$INSTALLED_NAMES" 2>/dev/null \
      | tr '[:upper:]' '[:lower:]' | tr '. ' '\n\n' | sort -u); do
    [ "${#vendor_token}" -lt 4 ] && continue
    case "$vendor_token" in
      com|org|net|io|co|group|app|apps|desktop|client|helper|shared|inc|llc) continue ;;
    esac
    [[ "$cand_lower" == *"$vendor_token"* ]] && return 0
  done
  return 1
}

# === Category A: Execution & Download History ===
section "Category A: Execution & Download History"

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
# macOS 27 writes .sfl4 files, and per-app recents live one level down in
# ApplicationRecentDocuments/. The old top-level *.sfl2/*.sfl3 glob matched nothing and
# still printed "cleared". The same directory also holds the Finder sidebar
# (FavoriteItems, FavoriteVolumes, TopSidebarSection, iCloudItems, ProjectsItems,
# NetworkBrowser), so only Recent* lists and the per-app directory are touched.
RI_DIR="$HOME_DIR/Library/Application Support/com.apple.sharedfilelist"
if [ -d "$RI_DIR" ]; then
  RI_COUNT=0
  for f in "$RI_DIR"/com.apple.LSSharedFileList.Recent*.sfl* \
           "$RI_DIR"/com.apple.LSSharedFileList.ApplicationRecentDocuments/*.sfl*; do
    [ -f "$f" ] || continue
    safe_trash "$f"
    RI_COUNT=$((RI_COUNT + 1))
  done
  if [ "$RI_COUNT" -gt 0 ]; then
    echo "Recent Items: cleared $RI_COUNT list(s) (Finder sidebar lists untouched)"
  else
    echo "Recent Items: nothing to clear"
  fi
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

# === Category B: Orphaned App Data (REPORT ONLY) ===
# Orphan detection is deny-listed by design: it deletes unless a hand-maintained
# skip list saves the item, so every newly installed app is a future false
# positive. It has already destroyed live data for installed apps (Google Drive,
# WhatsApp, Zoom, Shortcuts) whose container IDs do not resemble their bundle
# IDs, and it cannot see CLI tools, which own no .app bundle at all. Everything
# below is listed for review and deleted manually via Finder.
section "Category B: Orphaned App Data (report only)"

# Saved Application State (orphans)
SAS_DIR="$HOME_DIR/Library/Saved Application State"
if [ -d "$SAS_DIR" ]; then
  ORPHAN_COUNT=0
  for state_dir in "$SAS_DIR"/*/; do
    [ -d "$state_dir" ] || continue
    bundle_id=$(basename "$state_dir")
    is_apple_id "$bundle_id" && continue
    is_recently_modified "$state_dir" 30 && continue
    if ! matches_installed_app "$(normalize_bundle_id "$bundle_id")"; then
      report_candidate "$state_dir"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Saved Application State: $ORPHAN_COUNT orphan candidate(s)"
else
  echo "Saved Application State: not found"
fi

# Orphaned Containers (SIP-protected, cannot be moved by Terminal)
CONT_DIR="$HOME_DIR/Library/Containers"
if [ -d "$CONT_DIR" ]; then
  ORPHAN_COUNT=0
  for container in "$CONT_DIR"/*/; do
    [ -d "$container" ] || continue
    bundle_id=$(basename "$container")
    is_apple_id "$bundle_id" && continue
    [[ "$bundle_id" =~ ^[A-F0-9]{8}- ]] && continue
    is_recently_modified "$container" 30 && continue
    if ! matches_installed_app "$(normalize_bundle_id "$bundle_id")"; then
      report_candidate "${container%/}"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  if [ "$ORPHAN_COUNT" -gt 0 ]; then
    echo "Orphaned Containers: $ORPHAN_COUNT candidate(s) (SIP-protected — delete via Finder if needed)"
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
    is_apple_id "$gid" && continue
    is_recently_modified "$gc" 30 && continue
    if ! matches_installed_app "$(normalize_bundle_id "$gid")"; then
      report_candidate "$gc"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned Group Containers: $ORPHAN_COUNT orphan candidate(s)"
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
    is_apple_id "$storage_name" && continue
    # Strip .binarycookies suffix for matching
    match_name="${storage_name%.binarycookies}"
    # Skip system entries
    case "$match_name" in
      askpermissiond|crashpad-handler|familycircled) continue ;;
    esac
    is_recently_modified "$storage" 30 && continue
    if ! matches_installed_app "$(normalize_bundle_id "$match_name")"; then
      report_candidate "$storage"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned HTTPStorages: $ORPHAN_COUNT orphan candidate(s)"
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
    is_apple_id "$bundle_id" && continue
    is_recently_modified "$wk_entry" 30 && continue
    if ! matches_installed_app "$(normalize_bundle_id "$bundle_id")"; then
      report_candidate "$wk_entry"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned WebKit data: $ORPHAN_COUNT orphan candidate(s)"
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
    is_apple_id "$dir_name" && continue
    is_recently_modified "$support_dir" 30 && continue
    # Match by bundle ID (com.foo.bar style)
    if [[ "$dir_name" == *.*.* ]] && ! matches_installed_app "$(normalize_bundle_id "$dir_name")"; then
      report_candidate "$support_dir"
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
          report_candidate "$support_dir" "matched by name only — verify before deleting"
          ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
        fi
      fi
    fi
  done
  echo "Orphaned Application Support: $ORPHAN_COUNT orphan candidate(s)"
else
  echo "Application Support: not found"
fi

# Orphaned Preferences (plist files)
echo ""
section "Category B2: Orphaned Preferences"
PREF_DIR="$HOME_DIR/Library/Preferences"
if [ -d "$PREF_DIR" ]; then
  ORPHAN_COUNT=0
  # Known system/framework plists that are not app bundle IDs
  KNOWN_SYSTEM_PLISTS="loginwindow ByHost pbs sharedfilelistd corespotlightd diagnostics_agent mbuseragent icloudmailagent familycircled ContextStoreAgent ScopedBookmarkAgent MobileMeAccounts MiniLauncher SKGActivityJournal interpreter com.firebase.FIRInstallations com.claude.usagebar ChatGPTHelper cfx"
  for plist in "$PREF_DIR"/*.plist; do
    [ -f "$plist" ] || continue
    plist_name=$(basename "$plist" .plist)
    # Skip Apple plists. This must catch systemgroup.com.apple.* and
    # group.com.apple.* too — a prefix-only check on "com.apple." deleted
    # searchpartyd (Find My) settings.
    is_apple_id "$plist_name" && continue
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
    # App preferences are named by bundle ID, which always contains dots. A
    # bare name (TokenBucketRateLimiter) is framework-level, not an app.
    [[ "$plist_name" != *.* ]] && continue
    is_recently_modified "$plist" 30 && continue
    if ! matches_installed_app "$(normalize_bundle_id "$plist_name")"; then
      report_candidate "$plist"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned preferences: $ORPHAN_COUNT orphan candidate(s)"
else
  echo "Preferences: not found"
fi
echo ""

# Orphaned Application Scripts
section "Category B3: Orphaned Application Scripts"
ASCRIPT_DIR="$HOME_DIR/Library/Application Scripts"
if [ -d "$ASCRIPT_DIR" ]; then
  ORPHAN_COUNT=0
  for script_dir in "$ASCRIPT_DIR"/*/; do
    [ -d "$script_dir" ] || continue
    dir_name=$(basename "$script_dir")
    is_apple_id "$dir_name" && continue
    # Skip UUID-named dirs (system-managed)
    [[ "$dir_name" =~ ^[A-F0-9]{8}- ]] && continue
    is_recently_modified "$script_dir" 30 && continue
    if ! matches_installed_app "$(normalize_bundle_id "$dir_name")"; then
      report_candidate "$script_dir"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned Application Scripts: $ORPHAN_COUNT orphan candidate(s)"
else
  echo "Application Scripts: not found"
fi
echo ""

# Orphaned Caches (cross-reference against installed apps)
section "Category B4: Orphaned Caches"
OCACHE_DIR="$HOME_DIR/Library/Caches"
if [ -d "$OCACHE_DIR" ]; then
  ORPHAN_COUNT=0
  for cache_entry in "$OCACHE_DIR"/*/; do
    [ -d "$cache_entry" ] || continue
    cache_name=$(basename "$cache_entry")
    is_apple_id "$cache_name" && continue
    # Skip system/framework caches
    case "$cache_name" in
      CloudKit|FamilyCircle|GeoServices|claude-cli-nodejs|\
      Google|BraveSoftware|Firefox|Homebrew|pip|\
      Yarn|yarn|pnpm|uv|cargo|Composer|ms-playwright*) continue ;;
    esac
    # A cache named after a CLI tool (Codex, gh, etc.) has no .app bundle to
    # match against, so bundle-ID matching alone cannot tell it from an orphan.
    if command -v "$(echo "$cache_name" | tr '[:upper:]' '[:lower:]')" >/dev/null 2>&1; then
      continue
    fi
    is_recently_modified "$cache_entry" 30 && continue
    if ! matches_installed_app "$(normalize_bundle_id "$cache_name")"; then
      report_candidate "$cache_entry"
      ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
  done
  echo "Orphaned Caches: $ORPHAN_COUNT orphan candidate(s)"
else
  echo "Caches: not found"
fi
echo ""

# === Category C: Background Services ===
section "Category C: Background Services"

# Orphaned LaunchAgents (user)
LA_DIR="$HOME_DIR/Library/LaunchAgents"
if [ -d "$LA_DIR" ]; then
  ORPHAN_COUNT=0
  for plist in "$LA_DIR"/*.plist; do
    [ -f "$plist" ] || continue
    prog=$(/usr/libexec/PlistBuddy -c "Print ProgramArguments:0" "$plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Print Program" "$plist" 2>/dev/null || echo "")
    if [ -n "$prog" ] && [ ! -e "$prog" ]; then
      echo "  Orphaned LaunchAgent: $(basename "$plist") -> $prog"
      [ "$DRY_RUN" = 1 ] || launchctl bootout "gui/$(id -u)" "$plist" 2>/dev/null || true
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
section "Category D: Logs & Crash Reports"

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
section "Category E: Privacy Traces"

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
echo "=== Forensic Trace Cleanup Complete ==="
echo "$([ "$DRY_RUN" = 1 ] && echo "Would recover" || echo "Space recovered"): approximately $(format_size "$TOTAL_FREED") (moved to Trash)"
if [ "$REPORTED_COUNT" -gt 0 ]; then
  echo "Orphan candidates: $REPORTED_COUNT item(s), $(format_size $TOTAL_REPORTED) — NOT deleted"
  echo "  Review the list above and delete via Finder if you agree. Orphan"
  echo "  detection produces false positives for CLI tools, group containers,"
  echo "  and system frameworks that own no .app bundle."
fi
if [ "$TOTAL_FAILED" -gt 0 ]; then
  echo "Failed to trash: $TOTAL_FAILED item(s) — see errors above"
fi
echo ""
echo "NOTE: Some items (KnowledgeC, TCC database) may require manual deletion"
echo "via Finder due to macOS security protections. Never grant Full Disk Access"
echo "to Terminal for this purpose."

echo "Per-item log: $OPLOG"

finish_run

#!/bin/bash
set -m   # own process group per probe, so the watchdog can kill a probe's children
# Runner: executes the probe scripts for one mode in a single invocation, so the model
# makes one Bash call instead of ~28. Never aborts on a single script's failure.

BASE="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-full}"
PROBE_TIMEOUT="${DIAGNOSE_PROBE_TIMEOUT:-90}"   # seconds before a probe is considered hung

HARDWARE="system_info check_cpu check_memory check_problems check_battery check_disk_io check_thermal audit_background check_gpu check_disk_health"
NETWORK="check_network check_network_quality"
SECURITY="check_firewall check_encryption check_auth check_vpn check_updates check_threats check_infostealer_persistence check_infostealer_paths check_browser_credentials check_keychain check_malware_signatures check_app_signatures_quick check_network_exfiltration check_browser_security check_file_integrity"
BACKUP="check_backups"

case "$MODE" in
  full)     SCRIPTS="$HARDWARE $NETWORK $SECURITY $BACKUP" ;;
  hardware) SCRIPTS="$HARDWARE" ;;
  network)  SCRIPTS="$NETWORK" ;;
  security) SCRIPTS="$SECURITY" ;;
  *)
    echo "Usage: $(basename "$0") [full|hardware|network|security]" >&2
    exit 2
    ;;
esac

echo "########## /diagnose mode: $MODE ##########"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"

skipped=""
for s in $SCRIPTS; do
  echo ""
  echo "########## $s ##########"
  if [ ! -f "$BASE/$s.sh" ]; then
    echo "SKIPPED: $s.sh not found"
    skipped="$skipped $s(missing)"
    continue
  fi
  # Watchdog: macOS ships no coreutils `timeout`, and one hanging probe (as
  # `pmset -g thermlog` once did) would block the whole run forever. The probe writes to a
  # temp file rather than a pipe: a killed probe can leave children holding a pipe open,
  # which would keep command substitution blocked even after the probe itself is dead.
  tmp_out="${TMPDIR:-/tmp}/diagnose_$$_$s.out"
  : > "$tmp_out"
  bash "$BASE/$s.sh" > "$tmp_out" 2>&1 &
  probe=$!
  # Order matters: kill the probe first, then sweep its children. Killing a child first
  # just unblocks the parent, which then runs on to its own `exit 0` and reports success.
  # The marker file records that the watchdog fired, so a timeout is never misread as a
  # clean exit whatever code the dying probe happens to return.
  timeout_marker="$tmp_out.timeout"
  ( sleep "$PROBE_TIMEOUT"
    : > "$timeout_marker"
    # Note the children before killing the parent: once the parent dies its children are
    # reparented to launchd, and `pkill -P $probe` would then match nothing and leak them.
    kids=$(pgrep -P "$probe" 2>/dev/null)
    kill -9 "$probe" 2>/dev/null
    [ -n "$kids" ] && kill -9 $kids 2>/dev/null ) &
  watchdog=$!
  wait "$probe" 2>/dev/null
  rc=$?
  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  out=$(cat "$tmp_out" 2>/dev/null)
  timed_out=0
  [ -f "$timeout_marker" ] && timed_out=1
  rm -f "$tmp_out" "$timeout_marker"
  # Every probe script ends in `exit 0`, so a non-zero code here means the script did not
  # run to completion (syntax error, killed, missing interpreter) rather than "found nothing".
  if [ $rc -ne 0 ] || [ "$timed_out" -eq 1 ]; then
    if [ "$timed_out" -eq 1 ]; then
      echo "SKIPPED: $s exceeded ${PROBE_TIMEOUT}s and was killed (hung)"
      skipped="$skipped $s(hung)"
    else
      echo "SKIPPED: $s exited $rc before completing"
      skipped="$skipped $s(exit $rc)"
    fi
  elif [ -z "$out" ]; then
    echo "SKIPPED: $s produced no output"
    skipped="$skipped $s(no output)"
  fi
  [ -n "$out" ] && echo "$out"
done

echo ""
echo "########## RUN SUMMARY ##########"
echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
if [ -n "$skipped" ]; then
  echo "INCOMPLETE SCRIPTS:$skipped"
  echo "Score any category covered by these as incomplete, not clean."
else
  echo "All $(echo $SCRIPTS | wc -w | tr -d ' ') scripts completed."
fi

exit 0

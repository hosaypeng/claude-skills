#!/bin/bash
set -m   # own process group per probe, so the watchdog can kill a probe's children
# Runner: executes the probe scripts for one mode in a single invocation, so the model
# makes one Bash call instead of ~21. Never aborts on a single script's failure.
# Same contract as diagnose/run_diagnose.sh: every SKIPPED script is named, and the
# category it feeds must be scored as incomplete, never as clean.

BASE="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-full}"
PROBE_TIMEOUT="${THREAT_HUNT_PROBE_TIMEOUT:-90}"   # seconds before a probe is considered hung

PERSISTENCE="sweep_persistence sweep_xpc_services sweep_browser_extensions"
PROCESS="check_dylib_injection check_process_integrity check_sip_amfi check_temp_binaries"
NETWORK="scan_network_anomalies scan_network_processes scan_dns_c2"
IOC="match_ioc_files match_ioc_domains match_ioc_processes match_ioc_shutdown_log"
HARDENING="verify_hardening"
CREDENTIALS="scan_exposed_secrets scan_crypto_wallets scan_ssh_gpg_keys scan_browser_credentials scan_keychain_anomalies scan_clipboard_exfil"

case "$MODE" in
  full)        SCRIPTS="$PERSISTENCE $PROCESS $NETWORK $IOC $HARDENING $CREDENTIALS" ;;
  persistence) SCRIPTS="$PERSISTENCE" ;;
  process)     SCRIPTS="$PROCESS" ;;
  network)     SCRIPTS="$NETWORK" ;;
  ioc)         SCRIPTS="$IOC" ;;
  hardening)   SCRIPTS="$HARDENING" ;;
  credentials) SCRIPTS="$CREDENTIALS" ;;
  *)
    echo "Usage: $(basename "$0") [full|persistence|process|network|ioc|hardening|credentials]" >&2
    exit 2
    ;;
esac

echo "########## /threat-hunt mode: $MODE ##########"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "DISCLAIMER: This tool detects known indicators and configuration weaknesses. It CANNOT"
echo "detect zero-day exploits, in-memory-only implants, or kernel-level rootkits that have"
echo "bypassed SIP. For iOS-specific Pegasus detection, use MVT (Mobile Verification Toolkit)."

skipped=""
for s in $SCRIPTS; do
  echo ""
  echo "########## $s ##########"
  if [ ! -f "$BASE/$s.sh" ]; then
    echo "SKIPPED: $s.sh not found"
    skipped="$skipped $s(missing)"
    continue
  fi
  # Watchdog: macOS ships no coreutils `timeout`. The probe writes to a temp file rather
  # than a pipe: a killed probe can leave children holding a pipe open, which would keep
  # command substitution blocked even after the probe itself is dead.
  tmp_out="${TMPDIR:-/tmp}/threat_hunt_$$_$s.out"
  : > "$tmp_out"
  bash "$BASE/$s.sh" > "$tmp_out" 2>&1 &
  probe=$!
  # Kill the probe first, then sweep its children. Note the children before killing the
  # parent: once it dies they are reparented and `pgrep -P` would match nothing.
  timeout_marker="$tmp_out.timeout"
  ( sleep "$PROBE_TIMEOUT"
    : > "$timeout_marker"
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

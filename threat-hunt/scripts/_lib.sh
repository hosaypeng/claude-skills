#!/bin/bash
# Shared helpers for threat-hunt probe scripts. Source it; never run it.
#   source "$(dirname "$0")/_lib.sh"
# Probe scripts print what works and never abort on a failed sub-check (no set -e), and
# end in `exit 0`, so a non-zero exit always means "did not run to completion".

REFS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../references" 2>/dev/null && pwd)"

# Newest IOC file for a prefix (ioc_pegasus_, ioc_candiru_, ioc_domains_c2_). Empty if none.
latest_ioc() {
  local prefix="$1" f
  f=$(ls "$REFS_DIR"/"${prefix}"*.txt 2>/dev/null | sort | tail -1)
  [ -n "$f" ] && echo "$f"
  return 0
}

# Print an IOC file's date, age, and the staleness tag SKILL.md promises: MEDIUM at 30 days,
# CRITICAL at 90. A stale list that finds nothing is not reassurance.
ioc_staleness() {
  local file="$1" date days
  date=$(basename "$file" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
  if [ -z "$date" ]; then
    echo "  $(basename "$file"): undated - cannot assess staleness"
    return 0
  fi
  days=$(( ($(date +%s) - $(date -j -f "%Y-%m-%d" "$date" +%s 2>/dev/null || date +%s)) / 86400 ))
  echo "  $(basename "$file"): $date ($days days old)"
  if [ "$days" -ge 90 ]; then
    echo "  [CRITICAL] IOC list is over 90 days old - matches below are unverified, refresh it"
  elif [ "$days" -ge 30 ]; then
    echo "  [MEDIUM] IOC list is over 30 days old - refresh recommended"
  fi
  return 0
}

# Classify what a LaunchAgent/Daemon or plugin runs. Shell scripts can never be codesigned,
# so `codesign -v` on one is a guaranteed false HIGH; for scripts the real risk is a target a
# *different* account can rewrite, so those score on the group/other write bits.
# Ported from diagnose/check_infostealer_persistence.sh.
sig_status() {
  local target="$1" kind authority perm gw ow
  kind=$(file -b "$target" 2>&1)
  if echo "$kind" | grep -q "cannot open"; then
    echo "unreadable (root-only, mode $(stat -f "%OLp" "$target" 2>/dev/null)) - cannot verify signature"
  elif echo "$kind" | grep -qE "Mach-O|directory"; then
    if codesign -v "$target" >/dev/null 2>&1; then
      authority=$(codesign -dv --verbose=2 "$target" 2>&1 | sed -n 's/^Authority=//p' | head -1)
      echo "VALID - ${authority:-no authority (ad-hoc signature)}"
    else
      echo "[HIGH] UNSIGNED/INVALID Mach-O"
    fi
  else
    kind=$(echo "$kind" | cut -c1-40)
    # %OLp is not zero-padded (mode 020 prints "20"), so pad before slicing the digits.
    perm=$(printf '%03d' "$(stat -f "%OLp" "$target" 2>/dev/null || echo 0)")
    gw=$(printf "%s" "$perm" | cut -c2)
    ow=$(printf "%s" "$perm" | cut -c3)
    case "$gw$ow" in
      *[2367]*) echo "[HIGH] group/world-writable target, mode $perm ($kind)" ;;
      *)        echo "script, owner-writable only, mode $perm ($kind)" ;;
    esac
  fi
  return 0
}

# IPv4 dotted quad -> integer, for CIDR matching.
ip_to_int() {
  local IFS=. a b c d
  read -r a b c d <<< "$1"
  echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

# Owner label for an IPv4 address from references/known_good_networks.txt, or "unknown".
# Longest-prefix match, so 13.64.0.0/11 Azure beats 13.0.0.0/8 AWS. Annotation only: a hit
# never suppresses a finding, C2 on AWS is still C2.
ip_owner() {
  local ip="$1" ipn cidr owner net bits mask netn best="unknown" best_bits=-1
  case "$ip" in *.*.*.*) ;; *) echo "unknown"; return 0 ;; esac
  ipn=$(ip_to_int "$ip")
  while IFS='|' read -r cidr owner; do
    case "$cidr" in ''|\#*|*:*) continue ;; esac
    net="${cidr%/*}"; bits="${cidr#*/}"
    netn=$(ip_to_int "$net")
    mask=$(( bits == 0 ? 0 : (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF ))
    if [ $(( ipn & mask )) -eq $(( netn & mask )) ] && [ "$bits" -gt "$best_bits" ]; then
      best="$owner"; best_bits="$bits"
    fi
  done < "$REFS_DIR/known_good_networks.txt"
  echo "$best"
  return 0
}

# Interpreters that a LaunchAgent may wrap a script with. Anchored on a path separator so
# `sh$` cannot match ssh or fish.
INTERPRETERS='(^|/)(python[0-9.]*|ruby|node|perl|bash|zsh|sh|fish|dash|osascript)$'

# What a launchd plist really runs. Prints "<argv0>|<target>|<note>". When argv0 is an
# interpreter, the target is the first non-flag argument (the script), since verifying
# /bin/bash's Apple signature says nothing about the payload it was told to run. An inline
# `-c` command has no file to inspect and is reported as such.
resolve_plist_target() {
  local plist="$1" argv0 arg i target note=""
  argv0=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$plist" 2>/dev/null) \
    || argv0=$(/usr/libexec/PlistBuddy -c "Print :Program" "$plist" 2>/dev/null) \
    || { echo "||no Program or ProgramArguments readable"; return 0; }
  target="$argv0"
  if echo "$argv0" | grep -qE "$INTERPRETERS"; then
    target=""
    for i in 1 2 3 4 5; do
      arg=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:$i" "$plist" 2>/dev/null) || break
      case "$arg" in
        -c|-e) note="inline command: $(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:$((i + 1))" "$plist" 2>/dev/null | head -c 60)"; break ;;
        -m)    note="python module: $(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:$((i + 1))" "$plist" 2>/dev/null) (no file to classify; the venv dir is the trust boundary)"; break ;;
        -*) continue ;;
        *)  target="$arg"; break ;;
      esac
    done
    [ -z "$target" ] && [ -z "$note" ] && note="interpreter with no script argument"
  fi
  echo "$argv0|$target|$note"
  return 0
}

#!/bin/bash
# check_process_integrity.sh — Find unsigned and ad-hoc signed running processes
# Probe script: try each check, print what works, never abort on a failed sub-check.

# One pass over the process table. The previous two-loop version ran `ps -p` and codesign
# twice per PID and took ~32 s, a third of the whole hunt.
# Interpreter regex is anchored on a path separator: an unanchored `sh$` skipped ssh, fish
# and mosh, which are exactly the network-facing binaries worth checking.
INTERPRETERS='(^|/)(python[0-9.]*|ruby|node|perl|bash|zsh|sh|fish|dash)$'
HOMEBREW='^(/opt/homebrew/|/usr/local/Cellar/)'

# ps comm is not always a resolvable path: a process that rewrites its title (node apps,
# the Claude CLI) shows a bare or relative name. Those are resolved through lsof's txt
# entry; anything still unresolved is listed, because "could not check" must not read as
# "checked and fine".
resolve_binary() {
  local pid="$1" comm="$2"
  if [ -f "$comm" ]; then echo "$comm"; return 0; fi
  lsof -p "$pid" -a -d txt -Fn 2>/dev/null | sed -n '/^n\//{s/^n//p;q;}'
  return 0
}

unsigned=""
adhoc=""
unresolved=""
checked=0
while read -r pid comm; do
  [ "$comm" = "kernel_task" ] && continue
  [ "$comm" = "launchd" ] && continue
  [ -z "$comm" ] && continue
  binary=$(resolve_binary "$pid" "$comm")
  if [ -z "$binary" ] || [ ! -f "$binary" ]; then
    unresolved="$unresolved    PID $pid: $comm"$'\n'
    continue
  fi
  # Scripts and interpreters carry no signature; Homebrew formula binaries are ad-hoc by
  # design. Tested on the resolved path, since a bare title hides the Cellar prefix.
  echo "$binary" | grep -qE "$INTERPRETERS" && continue
  echo "$binary" | grep -qE "$HOMEBREW" && continue
  checked=$((checked + 1))
  result=$(codesign -dv "$binary" 2>&1)
  if echo "$result" | grep -q "not signed"; then
    unsigned="$unsigned  [HIGH] PID $pid: $binary — NOT SIGNED"$'\n'
  elif echo "$result" | grep -q "Signature=adhoc"; then
    adhoc="$adhoc  [HIGH] PID $pid: $binary — AD-HOC SIGNED"$'\n'
  fi
done < <(ps -eo pid=,comm= 2>/dev/null | sort -u -k2)

echo "=== Unsigned Running Processes ==="
if [ -n "$unsigned" ]; then
  printf '%s' "$unsigned" | head -20
else
  echo "  None found (good) — $checked binaries checked"
fi

echo "=== Ad-hoc Signed Processes (excluding Homebrew) ==="
# Ad-hoc = signed with no identity: a locally built binary, or something that wants to pass
# a "is it signed" check without a developer certificate. Expected only for your own builds.
if [ -n "$adhoc" ]; then
  printf '%s' "$adhoc" | head -20
else
  echo "  None found (good)"
fi

echo "=== Processes Not Resolvable to a Binary ==="
if [ -n "$unresolved" ]; then
  echo "  [INFO] $(printf '%s' "$unresolved" | grep -c .) process(es) could not be resolved to an on-disk binary (not verified):"
  printf '%s' "$unresolved" | head -15
else
  echo "  None"
fi

exit 0

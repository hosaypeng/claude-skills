#!/bin/bash
# sweep_xpc_services.sh — Enumerate launchd services in the system and user domains, flag non-Apple
# Probe script: try each check, print what works, never abort on a failed sub-check.

# `launchctl print <domain>` dumps domain metadata (bringup time, death port, subdomains)
# before the `services = { ... }` block. The old grep matched every indented line, so the
# "XPC services" list was 80 lines of launchd internals and no services. Extract the block.
list_domain_services() {
  local label="$1" domain="$2" block
  echo "=== $label (non-Apple) ==="
  block=$(launchctl print "$domain" 2>/dev/null | awk '/^\tservices = \{/{f=1;next} f&&/^\t\}/{exit} f')
  if [ -z "$block" ]; then
    echo "  SKIPPED: could not enumerate $domain (needs elevated privileges)"
    return 0
  fi
  block=$(echo "$block" | grep -v 'com\.apple\.' | awk '{print "  pid=" $1 " status=" $2 " " $3}')
  if [ -n "$block" ]; then echo "$block"; else echo "  None (all services are Apple)"; fi
  return 0
}

list_domain_services "System launchd services" system
list_domain_services "User launchd services" "gui/$(id -u)"

echo "=== Non-Apple Services via launchctl list ==="
# Same data from the unprivileged API, with last exit status: a non-zero status on a
# non-Apple label is a service that is crashing, which is where a broken implant shows up.
listed=$(launchctl list 2>/dev/null | grep -v 'com\.apple\.' | grep -v "^PID")
if [ -n "$listed" ]; then
  echo "$listed" | awk '{ tag = ($2 != "0" && $2 != "-") ? "[LOW] exit=" $2 " " : ""; print "  " tag $3 " (pid " $1 ")" }'
else
  echo "  SKIPPED: Could not list services"
fi

exit 0

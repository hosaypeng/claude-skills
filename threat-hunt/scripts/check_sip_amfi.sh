#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

# check_sip_amfi.sh — Check System Integrity Protection and Apple Mobile File Integrity

echo "=== SIP Status ==="
csrutil status 2>/dev/null || echo "  Could not determine SIP status"

echo "=== AMFI Status ==="
amfi=$(nvram -p 2>/dev/null | grep "amfi" || true)
if [ -n "$amfi" ]; then
  echo "  [MEDIUM] AMFI override detected: $amfi"
else
  echo "  AMFI: enabled (default, no override found)"
fi

exit 0

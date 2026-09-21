#!/bin/bash
# verify_hardening.sh — Verify physical-security mitigations and system hardening
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== FileVault Status ==="
fv_status=$(fdesetup status 2>/dev/null || echo "Could not determine")
echo "  $fv_status"
if echo "$fv_status" | grep -qi "off"; then
  echo "  [CRITICAL] FileVault is OFF — disk is readable with physical access"
fi

echo "=== Lockdown Mode ==="
ldm=$(defaults read .GlobalPreferences LDMGlobalEnabled 2>/dev/null || echo "not set")
if [ "$ldm" = "1" ]; then
  echo "  Lockdown Mode: ENABLED"
else
  echo "  Lockdown Mode: NOT ENABLED"
  echo "  [HIGH] Enable via System Settings > Privacy & Security > Lockdown Mode"
fi

echo "=== USB Restricted Mode (Accessories) ==="
# macOS 13+ on Apple Silicon defaults to "Ask for new accessories". No preference domain
# exposes the setting on macOS 27 (com.apple.security.accessory does not exist), so an
# absent key is the default and not a finding; it cannot be verified from the shell.
usb_mode=$(defaults read /Library/Preferences/com.apple.security.accessory USBRestrictedMode 2>/dev/null)
if [ -z "$usb_mode" ]; then
  echo "  not set (macOS default: Ask for new accessories)"
  echo "  [INFO] Not verifiable from the shell — confirm in System Settings > Privacy & Security > Accessories"
elif [ "$usb_mode" = "0" ]; then
  echo "  [MEDIUM] USB Restricted Mode explicitly disabled (accessories always allowed)"
else
  echo "  USBRestrictedMode: $usb_mode"
fi

echo "=== Firmware Password / Activation Lock ==="
if [ "$(uname -m)" = "arm64" ]; then
  echo "  Apple Silicon — Secure Boot policy and Activation Lock replace the firmware password"
  echo "  [INFO] Verify Activation Lock is on: System Settings > Apple Account > Find My"
else
  fw_status=$(firmwarepasswd -check 2>/dev/null || echo "Could not determine (may require admin)")
  echo "  $fw_status"
fi

echo "=== SIP Status ==="
sip=$(csrutil status 2>/dev/null || echo "Could not determine")
echo "  $sip"
if echo "$sip" | grep -qi "disabled"; then
  echo "  [CRITICAL] SIP is disabled"
fi

echo "=== Gatekeeper Status ==="
gk=$(spctl --status 2>/dev/null || echo "Could not determine")
echo "  $gk"
if echo "$gk" | grep -qi "disabled"; then
  echo "  [HIGH] Gatekeeper is disabled"
fi

echo "=== Automatic Updates ==="
# macOS 27 does not write these keys until the user toggles them, and an absent key means
# the default (enabled). Only a key that is present AND 0 is a finding.
read_su_key() {
  local key="$1" tag="$2" val
  val=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate "$key" 2>/dev/null)
  if [ -z "$val" ]; then
    echo "  $key: not set (macOS default: enabled)"
  elif [ "$val" = "0" ]; then
    echo "  ${tag}$key: 0 (explicitly disabled)"
  else
    echo "  $key: $val"
  fi
}
read_su_key AutomaticCheckEnabled "[MEDIUM] "
read_su_key AutomaticDownload ""
read_su_key CriticalUpdateInstall "[MEDIUM] "
read_su_key ConfigDataInstall ""

echo "=== Find My Mac ==="
# The fmm-mobileme-token NVRAM variable is an Intel-era artifact and is absent on Apple
# Silicon even with Find My on, so its absence was a guaranteed false LOW. What can be
# observed is whether the Find My daemons are alive; the setting itself needs the UI.
if pgrep -x findmydeviced >/dev/null 2>&1 && pgrep -x searchpartyd >/dev/null 2>&1; then
  echo "  findmydeviced and searchpartyd running (consistent with Find My on)"
else
  echo "  Find My daemons not running"
fi
if nvram -p 2>/dev/null | grep -q "fmm-mobileme-token"; then
  echo "  NVRAM Find My token present"
fi
echo "  [INFO] Confirm in System Settings > Apple Account > iCloud > Find My Mac"

echo "=== Screen Lock ==="
ask_pw=$(defaults read com.apple.screensaver askForPassword 2>/dev/null || echo "unknown")
ask_delay=$(defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo "unknown")
echo "  askForPassword: $ask_pw | askForPasswordDelay: $ask_delay"
if [ "$ask_pw" = "0" ]; then
  echo "  [HIGH] Screen lock password not required"
elif [[ "$ask_delay" =~ ^[0-9]+$ ]] && [ "$ask_delay" -gt 5 ]; then
  echo "  [LOW] Screen lock delay is $ask_delay seconds"
fi

echo "=== MVT Recommendation ==="
echo "  [INFO] For iOS-specific Pegasus detection, install MVT: pip3 install mvt"
echo "  [INFO] Run: mvt-ios check-backup --iocs pegasus.stix2 <backup_path>"

exit 0

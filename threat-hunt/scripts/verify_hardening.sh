#!/bin/bash
set -e

# verify_hardening.sh — Verify physical-security mitigations and system hardening

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

echo "=== USB Restricted Mode ==="
usb_mode=$(defaults read /Library/Preferences/com.apple.security.accessory USBRestrictedMode 2>/dev/null || echo "not set")
echo "  USB Restricted Mode: $usb_mode"
if [ "$usb_mode" = "not set" ] || [ "$usb_mode" = "0" ]; then
  echo "  [MEDIUM] USB Restricted Mode not confirmed — check System Settings > Privacy & Security > Accessories"
fi

echo "=== Firmware Password / Activation Lock ==="
arch=$(uname -m)
if [ "$arch" = "arm64" ]; then
  echo "  Apple Silicon detected — uses Activation Lock (cannot check programmatically)"
  echo "  [INFO] Verify Activation Lock is enabled via System Settings > Apple ID > Find My"
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
auto_check=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null || echo "unknown")
auto_download=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload 2>/dev/null || echo "unknown")
critical_install=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall 2>/dev/null || echo "unknown")
echo "  AutomaticCheck: $auto_check | AutomaticDownload: $auto_download | CriticalUpdateInstall: $critical_install"
if [ "$auto_check" = "0" ] || [ "$critical_install" = "0" ]; then
  echo "  [MEDIUM] Automatic updates are not fully enabled"
fi

echo "=== Find My Mac ==="
fmm=$(nvram -p 2>/dev/null | grep "fmm-mobileme-token" || true)
if [ -n "$fmm" ]; then
  echo "  Find My Mac: appears enabled"
else
  echo "  Find My Mac: token not found"
  echo "  [LOW] Find My Mac may be disabled"
fi

echo "=== Screen Lock ==="
ask_pw=$(defaults read com.apple.screensaver askForPassword 2>/dev/null || echo "unknown")
ask_delay=$(defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo "unknown")
echo "  askForPassword: $ask_pw | askForPasswordDelay: $ask_delay"
if [ "$ask_pw" = "0" ]; then
  echo "  [HIGH] Screen lock password not required"
elif [ "$ask_delay" != "unknown" ] && [ "$ask_delay" -gt 5 ] 2>/dev/null; then
  echo "  [LOW] Screen lock delay is $ask_delay seconds"
fi

echo "=== MVT Recommendation ==="
echo "  [INFO] For iOS-specific Pegasus detection, install MVT: pip3 install mvt"
echo "  [INFO] Run: mvt-ios check-backup --indicators pegasus.stix2 <backup_path>"

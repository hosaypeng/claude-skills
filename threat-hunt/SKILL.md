---
user-invocable: true
name: threat-hunt
description: "Detect nation-state spyware (Pegasus, Candiru/DevilsTongue), credential theft, and verify physical-security mitigations on macOS. Use when user says 'threat hunt', 'check for pegasus', 'spyware scan', 'am I being surveilled', 'nation-state', 'advanced threat', 'APT scan', 'check for spyware', or 'credential exposure'."
allowed-tools: Bash
argument-hint: "[full | persistence | process | network | ioc | hardening | credentials] (default: full)"
---

# Threat Hunt

`/diagnose` = commodity malware + system health. `/threat-hunt` = nation-state APTs, credential theft, and physical-security posture.

**Disclaimer (print at start of every run):**
> This tool detects known indicators and configuration weaknesses. It CANNOT detect zero-day exploits, in-memory-only implants, or kernel-level rootkits that have bypassed SIP. For iOS-specific Pegasus detection, use MVT (Mobile Verification Toolkit).

## Mode Routing

| Invocation | What runs |
|---|---|
| `/threat-hunt` or `/threat-hunt full` | All 6 categories |
| `/threat-hunt persistence` | Persistence sweep only |
| `/threat-hunt process` | Process integrity only |
| `/threat-hunt network` | Network anomalies only |
| `/threat-hunt ioc` | IOC matching only |
| `/threat-hunt hardening` | Hardening verification only |
| `/threat-hunt credentials` | Credential & secret exposure only |

## Scripts

Base path: `~/.claude/skills/threat-hunt/scripts/`. Run each as `bash <base>/<script>`.

**Persistence Sweep:** sweep_persistence, sweep_xpc_services, sweep_browser_extensions

**Process Integrity:** check_dylib_injection, check_process_integrity, check_sip_amfi, check_temp_binaries

**Network Anomalies:** scan_network_anomalies, scan_network_processes, scan_dns_c2

**IOC Matching:** match_ioc_files, match_ioc_domains, match_ioc_processes, match_ioc_shutdown_log

**Hardening:** verify_hardening

**Credential & Secret Exposure:** scan_exposed_secrets, scan_crypto_wallets, scan_ssh_gpg_keys, scan_browser_credentials, scan_keychain_anomalies, scan_clipboard_exfil

All scripts end in `.sh`.

## Domain Notes

- **IOC Staleness:** IOC files in `references/` have dates in filenames (e.g., `ioc_pegasus_2025-03-15.txt`). Scripts compute staleness from the filename date. Warn at 30 days, CRITICAL at 90 days. Always print the IOC date and staleness in output.
- **Code Signatures:** When checking codesign, "Apple Development" or ad-hoc on commercial software = suspicious. Unsigned LaunchAgent binary = HIGH. DYLD_INSERT_LIBRARIES in any plist = CRITICAL.
- **Lockdown Mode:** `defaults read .GlobalPreferences LDMGlobalEnabled 2>/dev/null`. Not all macOS versions support this; degrade gracefully.
- **Firmware Password:** Intel only (`firmwarepasswd -check`). Apple Silicon uses Activation Lock instead (cannot check programmatically — print INFO note).
- **Credential Scanning Safety:** NEVER print actual secret values, private keys, seed phrases, or passwords in output. Only report file path + pattern type matched.

## Output

Format per `~/.claude/skills/threat-hunt/references/output_format.md`. Produce a Threat Hunt Score (X/100) for any mode. After the report, ask if the user wants help fixing issues.

## Safety

- Never kill processes or disable security features without confirmation.
- Mark Claude sessions and system processes (WindowServer, kernel_task, launchd, coreaudiod) as PROTECTED.
- Never print actual secret values — only file paths and pattern types.
- If any CRITICAL finding: print incident response protocol from `references/incident_response_protocol.md`.
- Script fails with "Operation not permitted": skip, note as SKIPPED, continue.
- If IOC files are missing from references/: print warning and skip IOC mode, do not crash.

## Troubleshooting

- **"Operation not permitted" on launchctl print:** Some XPC enumeration requires root. Script will degrade with SKIPPED annotation.
- **Empty DNS cache:** Normal if recently flushed. `scan_dns_c2.sh` will note this and skip domain matching.
- **firmwarepasswd not found:** Expected on Apple Silicon. `verify_hardening.sh` detects architecture and adjusts.
- **No IOC files in references/:** `match_ioc_*.sh` scripts check for file existence first and skip gracefully.

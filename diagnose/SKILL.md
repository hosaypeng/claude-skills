---
user-invocable: true
name: diagnose
description: "Run comprehensive system diagnostics including hardware, network, and security. Use when user says 'diagnose my system', 'system health check', 'security audit', 'check performance', 'full diagnostics', 'am I secure', or 'scan for malware'."
allowed-tools: Bash
argument-hint: "[full | security | hardware | network] (default: full)"
---

# System Diagnostics

`/health-check` = fast daily pass/fail sweep. `/diagnose` = deep analysis when investigating problems.

## Mode Routing

| Invocation | What runs |
|---|---|
| `/diagnose` or `/diagnose full` | Hardware + Network + Security + Backups |
| `/diagnose security` | Security only |
| `/diagnose hardware` | Hardware only |
| `/diagnose network` | Network only |

## Scripts

Base path: `~/.claude/skills/diagnose/scripts/`. Run each as `bash <base>/<script>`.

**Hardware:** system_info, check_cpu, check_memory, check_problems, check_battery, check_disk_io, check_thermal, audit_background, check_gpu, check_disk_health

**Network:** check_network, check_network_quality

**Security:** check_firewall, check_encryption, check_auth, check_vpn, check_updates, check_threats, check_infostealer_persistence, check_infostealer_paths, check_browser_credentials, check_keychain, check_malware_signatures, check_app_signatures_quick, check_network_exfiltration, check_browser_security, check_file_integrity

**Backup (full mode only):** check_backups

All scripts end in `.sh`. For deeper app signature inspection, also available: check_app_signatures.sh (verbose) and check_app_signatures_highrisk.sh (piracy targets).

## Domain Notes
- **Battery:** Explain why Apple's reported % differs from actual (NominalChargeCapacity vs AppleRawMaxCapacity). Assess cell balance, cycle count, and recommend replace/keep.
- **DNS:** Flag non-standard servers (anything other than ISP default, 1.1.1.1, 8.8.8.8, 9.9.9.9, or known VPN DNS).
- **App signatures:** Cross-reference against known developers in output_format.md. "Apple Development" or ad-hoc on commercial software = suspicious.

## Output
Format per `~/.claude/skills/diagnose/references/output_format.md`. Produce a security score (X/100) for any mode that includes security. After the report, ask if the user wants help fixing issues.

## Safety
- Never kill processes or disable security features without confirmation.
- Mark Claude sessions and system processes (WindowServer, kernel_task) as PROTECTED.
- If known malware found: CRITICAL alert, recommend Malwarebytes scan + password rotation from clean device.
- Script fails with "Operation not permitted": skip, note as SKIPPED, continue.

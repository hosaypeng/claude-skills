---
user-invocable: true
name: diagnose
description: "Run comprehensive system diagnostics including hardware, network, and security. Use when user says 'diagnose my system', 'system health check', 'security audit', 'check performance', 'full diagnostics', 'am I secure', or 'scan for malware'."
allowed-tools: Bash, Read
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

Base path: `~/.claude/skills/diagnose/scripts/`.

**Run the mode in one call:** `bash ~/.claude/skills/diagnose/scripts/run_diagnose.sh <mode>`
where `<mode>` is `full`, `security`, `hardware`, or `network`. The runner executes every
script for that mode, delimits each with `########## <name> ##########`, and closes with a
RUN SUMMARY naming any script that failed to complete. Prefer it over invoking scripts one
by one. Individual scripts below remain runnable as `bash <base>/<script>.sh` when following
up on a single finding.

**Hardware:** system_info, check_cpu, check_memory, check_problems, check_battery, check_disk_io, check_thermal, audit_background, check_gpu, check_disk_health

**Network:** check_network, check_network_quality

**Security:** check_firewall, check_encryption, check_auth, check_vpn, check_updates, check_threats, check_infostealer_persistence, check_infostealer_paths, check_browser_credentials, check_keychain, check_malware_signatures, check_app_signatures_quick, check_network_exfiltration, check_browser_security, check_file_integrity

**Backup (full mode only):** check_backups

All scripts end in `.sh` and in `exit 0`, so a non-zero exit means the script did not run to
completion. For deeper app signature inspection, also available: check_app_signatures.sh
(verbose) and check_app_signatures_highrisk.sh (piracy targets).

Scripts tag their own findings inline with `[CRITICAL]`/`[HIGH]`/`[MEDIUM]`/`[LOW]`. Carry those
severities through to the report rather than re-deriving risk from raw output.

## Domain Notes
- **Battery:** Explain why Apple's reported % differs from actual (NominalChargeCapacity vs AppleRawMaxCapacity). Assess cell balance, cycle count, and recommend replace/keep.
- **DNS:** Flag non-standard servers (anything other than ISP default, 1.1.1.1, 8.8.8.8, 9.9.9.9, or known VPN DNS).
- **App signatures:** Cross-reference against known developers in output_format.md. "Apple Development" or ad-hoc on commercial software = suspicious. `CSSMERR_TP_CERT_REVOKED` is more serious than a missing sealed resource: the former means the developer certificate was revoked, the latter often just means the app self-updated.
- **Overlap with /threat-hunt:** the two skills deliberately maintain *parallel* implementations of the persistence, credential, keychain, and IOC checks so each runs standalone. This duplication is intentional - do not consolidate it. diagnose covers commodity stealers; threat-hunt covers nation-state implants and keeps its own Pegasus/Candiru IOC sets.

## Output
Format per `~/.claude/skills/diagnose/references/output_format.md`. Produce a security score (X/100) for any mode that includes security. After the report, ask if the user wants help fixing issues.

## Safety
- Never kill processes or disable security features without confirmation.
- Mark Claude sessions and system processes (WindowServer, kernel_task) as PROTECTED.
- If known malware found: CRITICAL alert, recommend Malwarebytes scan + password rotation from clean device.
- **Any** script that exits non-zero or produces no output is reported as SKIPPED *by name*, and the categories it feeds are scored as incomplete, never as clean. This covers "Operation not permitted" and every other failure, including a script that never ran at all.

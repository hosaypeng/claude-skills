---
user-invocable: true
name: diagnose
description: "Run comprehensive system diagnostics including hardware, network, and security. Use when user says 'diagnose my system', 'system health check', 'security audit', 'check performance', 'full diagnostics', 'am I secure', or 'scan for malware'."
allowed-tools: Bash, Read
argument-hint: "[full | security | hardware | network] (default: full)"
---

# System Diagnostics

`/health-check` = fast daily pass/fail sweep. `/diagnose` = deep analysis when investigating problems.

## Where the code lives

The engine is the `diagnose` CLI from **hosaypeng/diagnose** (`~/Code/diagnose`, symlinked to `~/.local/bin/diagnose`). This skill is a thin client: it runs the CLI with `-v` and turns the full output into the scored report, so what Claude does and what the user does at a prompt share one code path.

IF `diagnose` is not on PATH → tell the user to run `~/Code/diagnose/install.sh` (or clone the repo to `~/Code/diagnose` first). Do not reimplement any of it here.

## Mode Routing

| Invocation | What runs |
|---|---|
| `/diagnose` or `/diagnose full` | Hardware + Network + Security + Backups |
| `/diagnose security` | Security only |
| `/diagnose hardware` | Hardware only |
| `/diagnose network` | Network only |

## Execution

One Bash call: `diagnose <mode> -v` (timeout 300000 ms). `-v` streams every probe's output,
delimited by `########## <name> ##########`, and closes with a RUN SUMMARY naming any probe that
failed to complete, followed by the CLI's own findings digest. The full output is also saved to
`~/.claude/diagnose-last.txt`; `Read` it instead of re-running if the call's output was truncated.

Probe lists per mode: `diagnose --list <mode>`. A single probe can be re-run when following up on
one finding: `bash ~/Code/diagnose/scripts/<probe>.sh`. Two verbose signature probes are outside
every mode: `check_app_signatures.sh` (every app) and `check_app_signatures_highrisk.sh` (piracy targets).

Every probe ends in `exit 0`, so a non-zero exit means the script did not run to completion.
Probes tag their own findings inline with `[CRITICAL]`/`[HIGH]`/`[MEDIUM]`/`[LOW]`. Carry those
severities through to the report rather than re-deriving risk from raw output.

## Domain Notes
- **Battery:** macOS 27 exposes only `FullChargeCapacity`, `NominalChargeCapacity` and `DesignCapacity` (inside the `BatteryData` dict) plus `CycleCount`. The script prints Health = FullCharge/Design; compare it with Apple's "Maximum Capacity" (which uses NominalCharge) and explain the gap. Cell voltages, temperature and `AppleRawMaxCapacity` are no longer exposed - do not claim to assess cell balance. Recommend replace/keep from health % and cycles vs `DesignCycleCount9C`.
- **Apple Silicon:** no firmware password exists (Secure Boot policy replaces it); `check_encryption` reports "Not applicable" and it is never a deduction.
- **DNS:** Flag non-standard servers (anything other than ISP default, 1.1.1.1, 8.8.8.8, 9.9.9.9, or known VPN DNS).
- **App signatures:** Cross-reference against known developers in output_format.md. "Apple Development" or ad-hoc on commercial software = suspicious. `CSSMERR_TP_CERT_REVOKED` is more serious than a missing sealed resource: the former means the developer certificate was revoked, the latter often just means the app self-updated.
- **Browsers:** `check_browser_credentials` covers Chrome, Brave, Helium (`net.imput.helium`, the primary browser here), Arc and Firefox. Add a `scan_browser` line for any new Chromium-family browser; the profile layout is shared.
- **IOC staleness:** `check_malware_signatures` tags the stealer IOC list `[LOW]` only past 180 days (commodity paths rotate too fast for a tighter bound to mean much); threat-hunt uses 30/90 for its nation-state lists. `/health-check` warns on either at 90 days.
- **Overlap with /threat-hunt:** the two tools deliberately maintain *parallel* implementations of the persistence, credential, keychain, and IOC checks so each runs standalone. This duplication is intentional - do not consolidate it. diagnose covers commodity stealers; threat-hunt covers nation-state implants and keeps its own Pegasus/Candiru IOC sets. threat-hunt's `_lib.sh` `sig_status` and keychain predicate were ported *from* diagnose on 2026-09-21; keep the two in step when either changes.

## Compatibility
Verified end to end on macOS 27.0 (26A428), Apple M3, 2026-09-16. Safari prefs are read from the app container, kexts via `kmutil`, crash reports as `.ips`, battery from `BatteryData`, and absent SoftwareUpdate keys mean the default (enabled).

## Output
Format per `~/Code/diagnose/references/output_format.md`. Produce a security score (X/100) for any mode that includes security. After the report, ask if the user wants help fixing issues.

## Safety
- Never kill processes or disable security features without confirmation.
- Mark Claude sessions and system processes (WindowServer, kernel_task) as PROTECTED.
- If known malware found: CRITICAL alert, recommend Malwarebytes scan + password rotation from clean device.
- **Any** probe the RUN SUMMARY lists under INCOMPLETE SCRIPTS is reported as SKIPPED *by name*, and the categories it feeds are scored as incomplete, never as clean. This covers "Operation not permitted" and every other failure, including a script that never ran at all.

## Troubleshooting
- **`diagnose: command not found`:** run `~/Code/diagnose/install.sh`; it symlinks into `~/.local/bin` and warns if that is not on PATH.
- **A probe exceeded 90 s:** the runner kills it and lists it as `(hung)`. Re-run with `diagnose <mode> -v -t 180` on a loaded machine.
- **Fixing a probe:** edit it in `~/Code/diagnose/scripts/` and commit there — this skill directory holds only this file.

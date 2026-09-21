---
user-invocable: true
name: threat-hunt
description: "Detect nation-state spyware (Pegasus, Candiru/DevilsTongue), credential theft, and verify physical-security mitigations on macOS. Use when user says 'threat hunt', 'check for pegasus', 'spyware scan', 'am I being surveilled', 'nation-state', 'advanced threat', 'APT scan', 'check for spyware', or 'credential exposure'."
allowed-tools: Bash
argument-hint: "[full | persistence | process | network | ioc | hardening | credentials] (default: full)"
---

# Threat Hunt

`/diagnose` = commodity malware + system health. `/threat-hunt` = nation-state APTs, credential theft, and physical-security posture.

**Disclaimer (print at start of every run; the runner prints it too):**
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

Base path: `~/.claude/skills/threat-hunt/scripts/`.

**Run the mode in one call:** `bash ~/.claude/skills/threat-hunt/scripts/run_threat_hunt.sh <mode>`
where `<mode>` is `full`, `persistence`, `process`, `network`, `ioc`, `hardening`, or `credentials`.
The runner executes every script for that mode (~30 s for `full`), delimits each with
`########## <name> ##########`, and closes with a RUN SUMMARY naming any script that failed to
complete. Prefer it over invoking scripts one by one. Individual scripts remain runnable as
`bash <base>/<script>.sh` when following up on a single finding.

**Persistence:** sweep_persistence, sweep_xpc_services, sweep_browser_extensions

**Process Integrity:** check_dylib_injection, check_process_integrity, check_sip_amfi, check_temp_binaries

**Network Anomalies:** scan_network_anomalies, scan_network_processes, scan_dns_c2

**IOC Matching:** match_ioc_files, match_ioc_domains, match_ioc_processes, match_ioc_shutdown_log

**Hardening:** verify_hardening

**Credential & Secret Exposure:** scan_exposed_secrets, scan_crypto_wallets, scan_ssh_gpg_keys, scan_browser_credentials, scan_keychain_anomalies, scan_clipboard_exfil

All scripts end in `exit 0`, so a non-zero exit means the script did not run to completion. Shared
helpers (IOC staleness, signature classification, IP owner lookup) live in `_lib.sh`, which scripts
source and which is never run directly.

Scripts tag their own findings inline with `[CRITICAL]`/`[HIGH]`/`[MEDIUM]`/`[LOW]`/`[INFO]`. Carry
those severities through to the report rather than re-deriving risk from raw output.

## Domain Notes

- **IOC Staleness:** IOC files in `references/` are dated in the filename (`ioc_pegasus_2026-03-30.txt`). Every match script prints the date and age, tags `[MEDIUM]` at 30 days and `[CRITICAL]` at 90. Count the staleness deduction **once** in scoring, not once per script. A stale list that finds nothing means the IOC category is *unverified* — report it that way, never as clean. The internal `Last Updated` header of each file names the source publication date; the filename date is when the list was assembled here.
- **Code Signatures:** shell scripts and interpreters can never be code-signed, so `sig_status` classifies the LaunchAgent target first: Mach-O → codesign verdict; script → group/other write bits (owner-writable is normal for your own automation and scores 0); unreadable root-only helper → say so. An unsigned Mach-O behind a LaunchAgent is HIGH. `DYLD_INSERT_LIBRARIES` in any plist is CRITICAL. A plist whose target no longer exists is an orphan (LOW) — remove it so a future file at that path is not executed at login.
- **Persistence targets:** for `/bin/bash script.sh` or `python -m module` agents the thing classified is the script, not the Apple-signed interpreter (`resolve_plist_target`). An inline `-c` command or a plist with nothing readable is `[MEDIUM]`; a missing target is an orphan (`[LOW]`).
- **Unresolvable processes:** `ps` reports a bare name for processes that rewrite their title (node apps, the Claude CLI). `check_process_integrity` and `scan_network_processes` resolve those through `lsof`'s txt mapping; anything still unresolved is listed under `[INFO]` as *not verified* — never counted as checked.
- **Network filters** act on the remote endpoint only; the local `192.168.x.x` address must never be matched against the RFC1918 exclusion (that bug made the section always empty).
- **Password managers:** installed `.app` bundles and registered Safari extensions count, not only running processes. Apple Passwords / iCloud Keychain is not detectable from the shell.
- **Extensions:** Chromium-family browsers (Chrome, Brave, Helium, Arc, Edge) are listed with Web Store id, resolved name and version. Cross-check unfamiliar ids on the Web Store; an id with no store listing is sideloaded.
- **DNS cache:** `dscacheutil -cachedump` has not worked since macOS 10.x, so `scan_dns_c2` matches IOC domains against `/etc/hosts` and the URL hosts in Chromium-family and Safari browser history instead (read from a copy; only matched domains are ever printed). Safari needs Full Disk Access.
- **OPSEC:** `match_ioc_domains` actively resolves a sample of IOC domains from this machine. On a monitored network that generates DNS queries for known-bad domains. Run `ioc` mode only where that is acceptable; the other IOC scripts are passive.
- **Lockdown Mode:** `defaults read .GlobalPreferences LDMGlobalEnabled`. Absent = off.
- **Apple Silicon:** no firmware password (Secure Boot policy and Activation Lock replace it); USB Restricted Mode and Find My have no readable preference key on macOS 27. Both are reported `[INFO]` with the Settings path, never as a deduction. `fmm-mobileme-token` in NVRAM is Intel-era; its absence is not evidence.
- **Absent keys are defaults.** `AutomaticCheckEnabled` etc. print `not set (macOS default: enabled)` and score 0. Deduct only for a key that is present and 0.
- **Keychain access baseline:** ~30 events/hour idle on macOS 27 after excluding the `xpc` category and `makeUnlocked` chatter; the HIGH threshold is 100. Same predicate as `diagnose/check_keychain.sh`.
- **Seed phrases:** the heuristic matches the BIP39 shape (exactly 12/15/18/21/24 words of 3–8 lowercase letters, nothing else on the line). Prose lines in vault notes no longer fire.
- **Credential Scanning Safety:** NEVER print actual secret values, private keys, seed phrases, or passwords. Only report file path + pattern type matched.
- **Overlap with /diagnose:** the two skills deliberately maintain *parallel* implementations of the persistence, credential, keychain, and IOC checks so each runs standalone. This duplication is intentional — do not consolidate it. diagnose covers commodity stealers; threat-hunt covers nation-state implants and keeps its own Pegasus/Candiru IOC sets.

## Compatibility
Verified end to end on macOS 27.0 (26A428), Apple M3, 2026-09-21: 21/21 scripts complete in ~30 s under the runner with no false HIGHs on an idle machine.

## Output

Format per `~/.claude/skills/threat-hunt/references/output_format.md`. Produce a Threat Hunt Score (X/100) for any mode. After the report, ask if the user wants help fixing issues.

## Safety

- Never kill processes or disable security features without confirmation.
- Mark Claude sessions and system processes (WindowServer, kernel_task, launchd, coreaudiod) as PROTECTED.
- Never print actual secret values — only file paths and pattern types.
- If any CRITICAL finding other than IOC staleness: print the incident response protocol from `references/incident_response_protocol.md`.
- **Any** script the runner lists under INCOMPLETE SCRIPTS is reported as SKIPPED *by name*, and the category it feeds is scored as unverified, never as clean. This covers "Operation not permitted" and every other failure, including a script that never ran at all.
- If IOC files are missing from `references/`: the match scripts print SKIPPED and continue; score the IOC category as unverified.

## Troubleshooting

- **"Operation not permitted" on launchctl print:** system-domain enumeration can require root. `sweep_xpc_services` prints SKIPPED for that domain and continues with the user domain and `launchctl list`.
- **Login items "Could not enumerate":** Automation permission for System Events was not granted to the terminal. Not a finding.
- **`match_ioc_domains` slow:** dead IOC domains time out on resolution; `host -W 2` caps each at 2 s and only 25 are sampled.
- **A probe exceeded 90 s:** the runner kills it and lists it as `(hung)`. Raise `THREAT_HUNT_PROBE_TIMEOUT` if the machine is under load.
- **Refreshing IOCs:** save a new file under the same prefix with today's date (`ioc_pegasus_YYYY-MM-DD.txt`); the scripts pick the newest by name. Keep the `TYPE|VALUE|DESCRIPTION` format. Sources are named in each file's header; Amnesty's `AmnestyTech/investigations` repo publishes the Pegasus domain list.

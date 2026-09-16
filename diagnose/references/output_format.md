# Diagnose Output Reference

## Section Order
- **Full mode:** System Overview → Battery → GPU → Disk Health → Network → Security sections → Backup → Thermal → Problems → Top Resource Consumers → Recommendations → Key Findings
- **Hardware:** System Overview → Battery → GPU → Disk Health → Thermal → Problems → Resource Consumers
- **Network:** Network Quality → Active Connections
- **Security:** Security Posture Summary → all security sections → Recommendations → Score

## Risk Mappings
| Finding                        | Risk     |
|--------------------------------|----------|
| FileVault off                  | CRITICAL |
| Passwordless sudo              | CRITICAL |
| Known malware paths found      | CRITICAL |
| Invalid/unsigned commercial app | CRITICAL |
| Firewall disabled              | HIGH     |
| Unencrypted SSH keys           | HIGH     |
| Root account enabled           | HIGH     |
| Auto-login enabled             | MEDIUM   |
| Screen lock disabled           | MEDIUM   |
| Lock delay > 5 sec             | LOW      |

## Known Legitimate Developers
| Software         | Expected Authority                   |
|------------------|--------------------------------------|
| Adobe products   | Adobe Inc. (JQ525L2MZD)              |
| DaVinci Resolve  | Blackmagic Design Inc (9ZGFBWLSYP)   |
| Parallels        | Parallels International GmbH         |
| Microsoft Office | Microsoft Corporation (UBF8T346G9)   |
| CleanMyMac       | MacPaw Inc.                          |
| Final Draft      | Cast & Crew Production Software, LLC |
| JetBrains IDEs   | JetBrains s.r.o.                     |

## Security Score (X/100)

Start each category at full marks and subtract. **Every category floors at 0** - it can never
go negative or borrow from another category. Apply a deduction once, even if several scripts
report the same underlying condition.

| Category | Max | Deductions |
|---|---|---|
| Network Security | 15 | firewall disabled -8; stealth mode off -3; sensitive port listening -4; unrecognised external DNS resolver -2; loopback DNS with no local resolver running -6; proxy enabled unexpectedly -3 |
| Encryption | 15 | FileVault off -15; no firmware password -3; keychain has no lock timeout -2 |
| Authentication | 15 | passwordless sudo -15; root enabled -8; unencrypted SSH private key -6; auto-login enabled -5; screen lock disabled -5; lock delay > 5 sec -2 |
| Updates | 15 | pending security update -6; automatic checks disabled -4; Gatekeeper disabled -8 |
| Infostealer Detection | 20 | IOC path match -20; unsigned Mach-O in temp dir -12; non-browser process holding a credential DB -12; unsigned Mach-O behind a LaunchAgent/Daemon -8; LaunchAgent/Daemon target that is group- or world-writable -8; suspicious shell rc entry -8 |
| Threat Level | 10 | invalid/unsigned commercial app -10; revoked certificate -10; third-party kernel extension -4; unexplained root process -3 |
| Privacy | 10 | Safari fraud warnings off -4; tracking prevention off -3; unknown browser extension -3 |

Screen lock is scored under Authentication only - do not also deduct it under Encryption.

**DNS.** `127.0.0.1` / `::1` is the *expected* value when a local encrypting resolver is running
(dnscrypt-proxy, stubby, unbound, a local Pi-hole). Confirm with `pgrep -l "dnscrypt-proxy|stubby|unbound|named"`
before scoring: with a resolver running this is a hardening measure and scores **0**. Loopback DNS with
**no** resolver process is the actual red flag - that is a hijack shape, -6. Deduct -2 only for an
external resolver that is not the ISP default, 1.1.1.1, 8.8.8.8, 9.9.9.9, or a known VPN DNS.

**Writable LaunchAgent targets.** Owner-writable (`-rwxr-xr-x`) is normal for a user's own automation
scripts and scores **0** - report it as informational, not a finding. Deduct only when the target is
group- or world-writable (any of `-----w----`, `--------w-`), which lets a different account rewrite
what the agent executes.

**Incomplete scripts.** If `run_diagnose.sh` reports a script under INCOMPLETE SCRIPTS, the
categories it feeds are *unscored*, not full marks. Report the score as `X/100 (Y points
unverified)` and name the scripts. Never silently treat a missing check as a pass.

## Recommendations Format
Priority-ordered: CRITICAL → HIGH → MEDIUM → LOW. Each with specific action.

## If IOCs Found
1. Disconnect from network
2. Full Malwarebytes scan
3. Change all passwords from clean device
4. Check financial accounts
5. Consider full wipe if active compromise confirmed

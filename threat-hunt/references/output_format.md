# Threat Hunt Output Reference

## Disclaimer (always print first)

> **DISCLAIMER:** This tool detects known indicators and configuration weaknesses. It CANNOT detect zero-day exploits, in-memory-only implants, or kernel-level rootkits that have bypassed SIP. For iOS-specific Pegasus detection, use MVT (Mobile Verification Toolkit).

## Section Order

- **Full mode:** Disclaimer → IOC Staleness Banner → Persistence Sweep → Process Integrity → Network Anomalies → IOC Matches → Hardening Posture → Credential Exposure → Threat Hunt Score → Recommendations → Key Findings
- **persistence:** Disclaimer → Persistence Sweep → Score → Recommendations
- **process:** Disclaimer → Process Integrity → Score → Recommendations
- **network:** Disclaimer → Network Anomalies → Score → Recommendations
- **ioc:** Disclaimer → IOC Staleness Banner → IOC Matches → Score → Recommendations
- **hardening:** Disclaimer → Hardening Posture → Score → Recommendations
- **credentials:** Disclaimer → Credential Exposure → Score → Recommendations

## IOC Staleness Banner

Print after disclaimer when IOC mode is included:

```
IOC Database: Pegasus (YYYY-MM-DD, X days ago) | Candiru (YYYY-MM-DD, X days ago) | C2 Domains (YYYY-MM-DD, X days ago)
```

- < 30 days: no warning
- 30-89 days: `[MEDIUM] IOC lists are stale. Update recommended.`
- >= 90 days: `[CRITICAL] IOC lists are severely outdated. Update immediately.`

## Finding Format

Each finding follows this structure:

```
[SEVERITY] Finding Title
  What: Brief description of what was found
  Why:  Why this matters (threat model context)
  Do:   Specific remediation action
```

## Risk Mappings

| Finding | Severity |
|---|---|
| DYLD_INSERT_LIBRARIES in any plist | CRITICAL |
| Authorization plugin unsigned/non-Apple | CRITICAL |
| Any IOC file/hash/process/domain match | CRITICAL |
| SIP disabled | CRITICAL |
| FileVault off | CRITICAL |
| Plaintext private keys/seeds on disk | CRITICAL |
| .env with API keys world-readable | CRITICAL |
| Mach-O binary in /tmp unsigned | CRITICAL |
| Connection to known C2 IP/domain | CRITICAL |
| Ad-hoc signed running process | HIGH |
| Non-Apple XPC service | HIGH |
| Unsigned LaunchAgent binary | HIGH |
| Unsigned process with active network | HIGH |
| Hidden proxy configuration | HIGH |
| Lockdown Mode off | HIGH |
| Gatekeeper off | HIGH |
| Screen lock disabled | HIGH |
| Unencrypted SSH private keys | HIGH |
| Browser creds accessed by non-browser process | HIGH |
| Suspicious shell rc patterns | MEDIUM |
| Recent cron job added | MEDIUM |
| AMFI disabled | MEDIUM |
| Many connections to unknown IPs | MEDIUM |
| Auto-updates off | MEDIUM |
| USB Restricted Mode off | MEDIUM |
| No password manager detected | MEDIUM |
| Clipboard contains secret pattern | MEDIUM |
| ForwardAgent yes in SSH config | MEDIUM |
| IOC list > 90 days stale | MEDIUM |
| Stale periodic scripts | LOW |
| IOC list > 30 days stale | LOW |
| Find My Mac off | LOW |
| Screen lock delay > 5 sec | LOW |
| authorized_keys modified recently | LOW |

## Threat Hunt Score (X/100)

Raw scoring uses 6 categories at 20 points each (120 total), normalized to /100.

- Persistence Integrity: /20
- Process Integrity: /20
- Network Anomalies: /20
- IOC Matches: /20
- Hardening Posture: /20
- Credential Exposure: /20

**Deduction rules:** CRITICAL = -20 (zeros category), HIGH = -10, MEDIUM = -5, LOW = -2. Floor at 0 per category.

**Normalization:** `score = round(raw_total / 120 * 100)`

**When running a single mode:** Score only that category's /20, normalize to /100.

## Recommendations Format

Priority-ordered: CRITICAL → HIGH → MEDIUM → LOW. Each with specific action.

## If CRITICAL Finding

Print the incident response protocol from `references/incident_response_protocol.md`.

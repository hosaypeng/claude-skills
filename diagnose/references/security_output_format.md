# Diagnose Security Output Format

## Known Legitimate Developers (Reference)

| Software | Expected Authority |
|----------|-------------------|
| Adobe products | Adobe Inc. (JQ525L2MZD) |
| DaVinci Resolve | Blackmagic Design Inc (9ZGFBWLSYP) |
| Parallels | Parallels International GmbH |
| Microsoft Office | Microsoft Corporation (UBF8T346G9) |
| CleanMyMac | MacPaw Inc. |
| Final Draft | Cast & Crew Production Software, LLC |
| JetBrains IDEs | JetBrains s.r.o. |

## Security Report Format

#### Security Posture Summary
**Overall Risk Level:** LOW/MEDIUM/HIGH/CRITICAL

Quick metrics:
- Firewall: pass/fail
- FileVault: pass/fail
- Security updates: pass/warning/fail
- Remote access: Secure / Review / Exposed

---

#### Network Security
| Check | Status | Details |
|-------|--------|---------|
| Firewall | Enabled/Disabled | Block all: Y/N, Stealth: Y/N |
| Open Ports | N ports | List critical ones |
| DNS | Configured | Servers: X.X.X.X |
| VPN | Active/Inactive | Connection details |
| Proxy | None/Configured | Details if configured |

**Issues:** List any concerns

---

#### Encryption & Protection
| Check | Status | Risk |
|-------|--------|------|
| FileVault | On/Off | CRITICAL if off |
| Firmware Password | Set/Unknown/Not set | HIGH if not set |
| Screen Lock | Enabled/Disabled | MEDIUM if disabled |
| Lock Delay | Immediate/X sec | LOW if >5sec |

**Issues:** List any concerns

---

#### Authentication & Access
| Check | Status | Risk |
|-------|--------|------|
| Sudo | Requires password/Passwordless | CRITICAL if passwordless |
| SSH Keys | N found | Details |
| Unencrypted Keys | N found | HIGH if >0 |
| Root Account | Disabled/Enabled | HIGH if enabled |
| Auto-login | Disabled/Enabled | MEDIUM if enabled |
| Remote Login | Off/On | Info about ports |
| Screen Sharing | Off/On | Info about access |

**Issues:** List any concerns

---

#### Updates & Patches
| Check | Status |
|-------|--------|
| Pending Updates | N updates |
| Last Check | Date/time |
| Auto Check | Enabled/Disabled |
| Auto Install | Enabled/Disabled |
| Gatekeeper | Enabled/Disabled |

**Issues:** List critical updates

---

#### Suspicious Activity
| Category | Count | Details |
|----------|-------|---------|
| Recent Crashes | N | App names |
| Kernel Panics | N | Dates |
| Root Processes | N suspicious | Process names |
| Hidden Files | N | Locations |
| Login Items | N | Names |
| Kernel Extensions | N non-Apple | Names |

**Threat Assessment:** Analysis

---

#### Infostealer Detection
| Check | Status | Risk |
|-------|--------|------|
| LaunchAgents/Daemons | Clean/Suspicious entries | Details |
| Hidden Directories | None/Found | Locations |
| Browser Credential Access | Normal/Recent suspicious | Details |
| Keychain Access | Normal/Anomalies detected | Details |
| Known Malware Paths | Clean/IOCs found | CRITICAL if found |
| Suspicious Network | Normal/Exfiltration indicators | IPs/Ports |

**Infostealer Risk:** None detected / Indicators found / Active compromise suspected

**If IOCs Found:**
1. Disconnect from network immediately
2. Run full Malwarebytes scan
3. Change all passwords from a clean device
4. Check financial accounts for unauthorized access
5. Consider full system wipe if active compromise confirmed

---

#### Application Signature Audit
**Total Apps Scanned:** N applications

| Status | Count | Apps |
|--------|-------|------|
| Valid (Developer ID) | N | List legitimate apps |
| Valid (Apple) | N | System apps |
| Ad-hoc/Development | N | Apps needing review |
| Unsigned/Invalid | N | **CRITICAL** - List apps |

**High-Risk Category Apps (Piracy Targets):**
| App | Signature Status | Authority | Risk |
|-----|-----------------|-----------|------|
| Adobe Photoshop | Valid/Invalid | Adobe Inc. / Unknown | Details |
| DaVinci Resolve | Valid/Invalid | Blackmagic / Unknown | Details |
| Microsoft Office | Valid/Invalid | Microsoft / Unknown | Details |
| [Other flagged apps] | ... | ... | ... |

**Signature Issues Found:**
- List any apps with invalid/missing signatures
- List any apps where Authority doesn't match expected developer
- List any ad-hoc signed apps that should be Developer ID signed

**Recommendations:**
- Unsigned apps: Remove or verify source and reinstall from official source
- Mismatched authority: Verify app was downloaded from official source
- All clear: App signatures verified

---

#### Browser Security (Safari & Chrome)
| Check | Status |
|-------|--------|
| Fraudulent Site Warnings | Enabled/Disabled |
| Do Not Track | Enabled/Disabled |
| Extensions | N installed |
| Privacy Score | Good/Review |

---

#### File Integrity
| Check | Status |
|-------|--------|
| Sudoers Permissions | Secure/Insecure |
| Hosts File | Clean/Modified |
| World-Writable Files | N found |

---

#### Security Recommendations
Priority-ordered, most critical first:

**CRITICAL (Fix immediately):**
1. [List critical issues like: "Enable FileVault", "Enable Firewall"]

**HIGH (Fix soon):**
2. [List high-priority issues]

**MEDIUM (Review):**
3. [List medium-priority issues]

**LOW (Best practices):**
4. [List nice-to-have improvements]

---

#### Security Score

**Overall: X/100**

Breakdown:
- Network Security: X/15
- Encryption: X/15
- Authentication: X/15
- Updates: X/15
- Infostealer Detection: X/20
- Threat Level: X/10
- Privacy: X/10

**Summary:** Brief assessment of security posture

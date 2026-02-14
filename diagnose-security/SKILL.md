---
name: diagnose-security
description: "Run comprehensive security audit including firewall, FileVault, open ports, VPN, suspicious processes, login items, security updates, infostealer detection, and app signature verification. Use when user says 'security audit', 'check my security', 'am I secure', 'scan for malware', or 'security check'."
allowed-tools: Bash
---

# Security Diagnostics Skill

Run a comprehensive security audit to identify vulnerabilities, misconfigurations, and potential threats.

## Instructions

When invoked, run the following security checks and present results in a clear, actionable format:

### 1. Firewall & Network Security
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_firewall.sh
```

**Present:**
- Firewall: Enabled/Disabled
- Block all incoming: Yes/No
- Stealth mode: Yes/No
- Open ports: List with process names
- Sensitive ports exposed: List any concerns
- DNS servers: Are they trusted?
- Proxy: Configured/None

### 2. Encryption & Data Protection
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_encryption.sh
```

**Present:**
- FileVault: On/Off
- Firmware password: Set/Not set (if checkable)
- Screen lock: Enabled/Disabled
- Screen lock delay: Immediate/X seconds
- Security score: Good/Needs improvement

### 3. Authentication & Access Control
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_auth.sh
```

**Present:**
- Sudo: Requires password/Passwordless (RISK)
- SSH keys: N found
- Unencrypted keys: Count (RISK if >0)
- Root account: Disabled/Enabled
- Auto-login: Disabled/Enabled (RISK)

### 4. VPN & Remote Access
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_vpn.sh
```

**Present:**
- VPN: Active connections or None
- Screen sharing: Enabled/Disabled
- Remote login (SSH): On/Off
- Remote management: On/Off
- Remote access summary: Secure/Review needed

### 5. Software Updates & Patches
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_updates.sh
```

**Present:**
- Pending security updates: Count
- Last update check: Date
- Automatic checks: Enabled/Disabled
- Automatic install: Enabled/Disabled
- Gatekeeper: Enabled/Disabled
- Update posture: Current/Needs updates

### 6. Suspicious Activity & Threats
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_threats.sh
```

**Present:**
- Recent crashes: N apps (list names)
- Kernel panics: N (last 7 days)
- Suspicious root processes: List
- Hidden files: Count in sensitive locations
- Login items: List
- Third-party kernel extensions: List
- Threat level: Low/Medium/High

### 7. Infostealer Detection

This section specifically targets macOS infostealers commonly distributed through pirated software (Adobe, CleanMyMac, Parallels, DaVinci Resolve, Microsoft Office, etc.).

#### 7.1 Persistence Mechanism Audit
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_infostealer_persistence.sh
```

**Analyze each plist file for:**
- Unknown or suspicious labels (random strings, misspellings of legitimate services)
- Programs pointing to unusual locations (`/tmp`, `/var/tmp`, hidden folders)
- `RunAtLoad` with `KeepAlive` for unknown services
- Programs with obfuscated names or in user-writable locations

#### 7.2 Known Infostealer Paths & Patterns
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_infostealer_paths.sh
```

#### 7.3 Browser Credential Store Audit
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_browser_credentials.sh
```

#### 7.4 Keychain Access Audit
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_keychain.sh
```

#### 7.5 Known Malware Signatures
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_malware_signatures.sh
```

#### 7.6 Application Integrity Check (All Desktop Apps)

Scan ALL applications in /Applications to verify code signatures and detect potentially compromised software.

**Full verbose scan:**
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_app_signatures.sh
```

**Quick scan with summary output (faster):**
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_app_signatures_quick.sh
```

**High-risk categories (common piracy targets):**
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_app_signatures_highrisk.sh
```

**What to look for:**
- **Valid**: Authority shows legitimate developer name (e.g., "Developer ID Application: Adobe Inc.")
- **Suspicious**: Authority shows "Apple Development" or ad-hoc signature
- **CRITICAL**: "code signature invalid", "unsigned", or missing TeamIdentifier
- **CRITICAL**: Authority doesn't match expected developer (e.g., Adobe app not signed by Adobe)

**Known legitimate developers (reference):**
| Software | Expected Authority |
|----------|-------------------|
| Adobe products | Adobe Inc. (JQ525L2MZD) |
| DaVinci Resolve | Blackmagic Design Inc (9ZGFBWLSYP) |
| Parallels | Parallels International GmbH |
| Microsoft Office | Microsoft Corporation (UBF8T346G9) |
| CleanMyMac | MacPaw Inc. |
| Final Draft | Cast & Crew Production Software, LLC |
| JetBrains IDEs | JetBrains s.r.o. |

#### 7.7 Network Exfiltration Indicators
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_network_exfiltration.sh
```

**Present Infostealer Analysis:**

| Check | Status | Risk Level |
|-------|--------|------------|
| LaunchAgents | Clean/Suspicious | LOW/MEDIUM/HIGH |
| Hidden Directories | None/Found | Details |
| Browser Credentials | Normal/Recently Accessed | Details |
| Keychain | Normal/Suspicious Access | Details |
| Known Malware Paths | Clean/Found | CRITICAL if found |
| App Signatures | Valid/Invalid/Missing | Details |
| Network Activity | Normal/Suspicious | Details |

**Infostealer-Specific Recommendations:**
- If ANY known malware patterns found: Run full Malwarebytes scan immediately
- If suspicious LaunchAgents found: Disable and quarantine for analysis
- If browser credentials recently accessed by unknown process: Change all passwords
- If keychain shows suspicious access: Revoke and rotate all stored credentials

---

### 8. Browser Security (Safari & Chrome)
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_browser_security.sh
```

**Present:**
- Fraudulent site warnings: Enabled/Disabled
- Do Not Track: Enabled/Disabled
- Extensions installed: List
- Privacy score: Good/Review needed

### 9. File Permissions & Integrity
```bash
bash ~/.claude/skills/diagnose-security/scripts/check_file_integrity.sh
```

**Present:**
- Sudoers permissions: Secure/Insecure
- Hosts file: Clean/Modified (list entries)
- World-writable files: Count
- File integrity: Good/Issues found

### 10. Present Security Report

Format the output as:

#### 🔒 Security Posture Summary
**Overall Risk Level:** LOW/MEDIUM/HIGH/CRITICAL

Quick metrics:
- Firewall: ✅/❌
- FileVault: ✅/❌
- Security updates: ✅/⚠️/❌
- Remote access: ✅ Secure / ⚠️ Review / ❌ Exposed

---

#### 🛡️ Network Security
| Check | Status | Details |
|-------|--------|---------|
| Firewall | Enabled/Disabled | Block all: Y/N, Stealth: Y/N |
| Open Ports | N ports | List critical ones |
| DNS | Configured | Servers: X.X.X.X |
| VPN | Active/Inactive | Connection details |
| Proxy | None/Configured | Details if configured |

**Issues:** List any concerns

---

#### 🔐 Encryption & Protection
| Check | Status | Risk |
|-------|--------|------|
| FileVault | On/Off | CRITICAL if off |
| Firmware Password | Set/Unknown/Not set | HIGH if not set |
| Screen Lock | Enabled/Disabled | MEDIUM if disabled |
| Lock Delay | Immediate/X sec | LOW if >5sec |

**Issues:** List any concerns

---

#### 👤 Authentication & Access
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

#### 🔄 Updates & Patches
| Check | Status |
|-------|--------|
| Pending Updates | N updates |
| Last Check | Date/time |
| Auto Check | Enabled/Disabled |
| Auto Install | Enabled/Disabled |
| Gatekeeper | Enabled/Disabled |

**Issues:** List critical updates

---

#### ⚠️ Suspicious Activity
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

#### 🦠 Infostealer Detection
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

#### 📱 Application Signature Audit
**Total Apps Scanned:** N applications

| Status | Count | Apps |
|--------|-------|------|
| ✅ Valid (Developer ID) | N | List legitimate apps |
| ✅ Valid (Apple) | N | System apps |
| ⚠️ Ad-hoc/Development | N | Apps needing review |
| ❌ Unsigned/Invalid | N | **CRITICAL** - List apps |

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
- ❌ Unsigned apps: Remove or verify source and reinstall from official source
- ⚠️ Mismatched authority: Verify app was downloaded from official source
- ✅ All clear: App signatures verified

---

#### 🌐 Browser Security (Safari & Chrome)
| Check | Status |
|-------|--------|
| Fraudulent Site Warnings | Enabled/Disabled |
| Do Not Track | Enabled/Disabled |
| Extensions | N installed |
| Privacy Score | Good/Review |

---

#### 📁 File Integrity
| Check | Status |
|-------|--------|
| Sudoers Permissions | Secure/Insecure |
| Hosts File | Clean/Modified |
| World-Writable Files | N found |

---

#### ✅ Security Recommendations
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

#### 🎯 Security Score

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

### 11. Offer to Help
After presenting the report, ask:
"Would you like me to help fix any of these security issues? I can:
1. Enable FileVault (requires restart)
2. Enable Firewall
3. Configure automatic updates
4. Review and close unnecessary open ports
5. Other security hardening

Specify the numbers or type 'all critical' to address critical issues."

## Safety Rules
- Never disable security features without explicit user confirmation
- Always warn before making security configuration changes
- Explain the impact of each recommended change
- Prioritize data protection over convenience
- Mark any findings that could indicate compromise as CRITICAL

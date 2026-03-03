---
user-invocable: true
name: diagnose
description: "Run comprehensive system diagnostics including hardware, network, and security. Use when user says 'diagnose my system', 'system health check', 'security audit', 'check performance', 'full diagnostics', 'am I secure', or 'scan for malware'."
allowed-tools: Bash
argument-hint: "[full | security | hardware | network] (default: full)"
---

# System Diagnostics Skill

Run system diagnostics to identify resource bottlenecks, security vulnerabilities, hardware issues, and network problems.

## When to use this vs /health-check

| | `/health-check` | `/diagnose` |
|-|------------------|-------------|
| **Purpose** | Quick pass/fail across all systems | Deep analysis of specific subsystems |
| **Runtime** | < 30 seconds | Minutes (varies by mode) |
| **Scope** | LaunchAgents, git repos, backups, habits, CLAUDE.md | Hardware, security, network, disk, GPU, threats |
| **Output** | "All healthy" or grouped failures with remediation | Detailed report with metrics, tables, and risk levels |
| **Use when** | Daily check, "is everything working?" | Investigating a specific problem, security audit, performance troubleshooting |

Use `/health-check` for a fast daily sweep. Use `/diagnose` when something feels wrong or you need a thorough audit of a specific area.

## Mode Routing

| Invocation | Mode | What runs |
|---|---|---|
| `/diagnose` or `/diagnose full` | Full | Hardware + Network + Deep Security + Backups |
| `/diagnose security` | Security | Deep security audit only (firewall, encryption, auth, threats, infostealers, app signatures) |
| `/diagnose hardware` | Hardware | CPU, memory, battery, GPU, thermal, disk health |
| `/diagnose network` | Network | Network quality + active connections |

---

## Full Mode

Runs all sections below in order: Hardware, Network, Deep Security, Backups.

---

## Hardware Mode

### 1. System Info
```bash
bash ~/.claude/skills/diagnose/scripts/system_info.sh
```

### 2. CPU Usage
```bash
bash ~/.claude/skills/diagnose/scripts/check_cpu.sh
```

### 3. Memory Usage
```bash
bash ~/.claude/skills/diagnose/scripts/check_memory.sh
```

### 4. Problem Processes
```bash
bash ~/.claude/skills/diagnose/scripts/check_problems.sh
```

### 5. Battery Health (macOS only)
```bash
bash ~/.claude/skills/diagnose/scripts/check_battery.sh
```

**Present battery findings in a table:**
| Metric | Value | Status |
|--------|-------|--------|
| Actual Capacity | X% (raw) vs Y% (nominal) | Below 80% / Healthy |
| Cycle Count | N cycles | Exceeded 1,000 / Within design life |
| Cell Balance | XmV variance | Excellent / Concerning |
| Temperature | X°C | Normal / Warning |
| Permanent Failure | None / Detected | Hardware is fine / ALERT |

**Analysis to include:**
- Why Apple's reported % differs from actual (NominalChargeCapacity vs AppleRawMaxCapacity)
- Whether battery shows healthy aging (balanced cells, no permanent failures)
- Estimated runtime impact (% degradation = % less runtime)
- Cycle rate analysis if historical data available
- Recommendation: "Replace when convenient" or "Immediate replacement needed"

### 6. Disk I/O Performance
```bash
bash ~/.claude/skills/diagnose/scripts/check_disk_io.sh
```

**Present:**
- Disk usage: X GB / Y GB (Z% used)
- I/O load: Read/Write MB/s
- Processes in disk wait state (if any)

### 7. Thermal Status
```bash
bash ~/.claude/skills/diagnose/scripts/check_thermal.sh
```

**Present:**
- Thermal pressure status
- CPU throttling: Yes/No

### 8. Background Process Audit
```bash
bash ~/.claude/skills/diagnose/scripts/audit_background.sh
```

**Present:**
- User launch agents: N active
- High-impact background processes

### 9. GPU & Graphics Performance
```bash
bash ~/.claude/skills/diagnose/scripts/check_gpu.sh
```

**Present:**
- GPU model and VRAM
- GPU utilization % (if available)
- GPU memory used/free
- Top GPU consumers
- Connected displays

### 10. Disk Health (SMART Status)
```bash
bash ~/.claude/skills/diagnose/scripts/check_disk_health.sh
```

**Present:**
- SMART status: Verified/Failing
- SSD wear level (if available)
- Drive temperature
- Disk errors (last 24h)
- Estimated health: Excellent/Good/Warning/Critical

---

## Network Mode

### 1. Network Activity
```bash
bash ~/.claude/skills/diagnose/scripts/check_network.sh
```

**Present:**
- Active connections: N
- Top network-using processes

### 2. Network Throughput & Quality
```bash
bash ~/.claude/skills/diagnose/scripts/check_network_quality.sh
```

**Present:**
- Network interface: Active interface name
- WiFi signal: -XX dBm (Excellent/Good/Fair/Poor)
- WiFi speed: Current/Max Mbps
- Packet loss/errors: Count
- Top bandwidth consumers

---

## Security Mode

Deep security audit covering firewall, encryption, authentication, threats, infostealers, browser security, and file integrity.

### 1. Firewall & Network Security
```bash
bash ~/.claude/skills/diagnose/scripts/check_firewall.sh
```

**Present:**
- Firewall: Enabled/Disabled
- Block all incoming: Yes/No
- Stealth mode: Yes/No
- Open ports: List with process names
- Sensitive ports exposed: List any concerns
- DNS servers: List configured servers. Flag non-standard DNS (anything other than ISP default, 1.1.1.1, 8.8.8.8, 9.9.9.9, or known VPN DNS) as 'Review recommended'.
- Proxy: Configured/None

### 2. Encryption & Data Protection
```bash
bash ~/.claude/skills/diagnose/scripts/check_encryption.sh
```

**Present:**
- FileVault: On/Off
- Firmware password: Set/Not set (if checkable)
- Screen lock: Enabled/Disabled
- Screen lock delay: Immediate/X seconds
- Security score: Good/Needs improvement

### 3. Authentication & Access Control
```bash
bash ~/.claude/skills/diagnose/scripts/check_auth.sh
```

**Present:**
- Sudo: Requires password/Passwordless (RISK)
- SSH keys: N found
- Unencrypted keys: Count (RISK if >0)
- Root account: Disabled/Enabled
- Auto-login: Disabled/Enabled (RISK)

### 4. VPN & Remote Access
```bash
bash ~/.claude/skills/diagnose/scripts/check_vpn.sh
```

**Present:**
- VPN: Active connections or None
- Screen sharing: Enabled/Disabled
- Remote login (SSH): On/Off
- Remote management: On/Off
- Remote access summary: Secure/Review needed

### 5. Software Updates & Patches
```bash
bash ~/.claude/skills/diagnose/scripts/check_updates.sh
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
bash ~/.claude/skills/diagnose/scripts/check_threats.sh
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
bash ~/.claude/skills/diagnose/scripts/check_infostealer_persistence.sh
```

**Analyze each plist file for:**
- Unknown or suspicious labels (random strings, misspellings of legitimate services)
- Programs pointing to unusual locations (`/tmp`, `/var/tmp`, hidden folders)
- `RunAtLoad` with `KeepAlive` for unknown services
- Programs with obfuscated names or in user-writable locations

#### 7.2 Known Infostealer Paths & Patterns
```bash
bash ~/.claude/skills/diagnose/scripts/check_infostealer_paths.sh
```

#### 7.3 Browser Credential Store Audit
```bash
bash ~/.claude/skills/diagnose/scripts/check_browser_credentials.sh
```

#### 7.4 Keychain Access Audit
```bash
bash ~/.claude/skills/diagnose/scripts/check_keychain.sh
```

#### 7.5 Known Malware Signatures
```bash
bash ~/.claude/skills/diagnose/scripts/check_malware_signatures.sh
```

#### 7.6 Application Integrity Check (All Desktop Apps)

Scan ALL applications in /Applications to verify code signatures and detect potentially compromised software.

**Full verbose scan:**
```bash
bash ~/.claude/skills/diagnose/scripts/check_app_signatures.sh
```

**Quick scan with summary output (faster):**
```bash
bash ~/.claude/skills/diagnose/scripts/check_app_signatures_quick.sh
```

**High-risk categories (common piracy targets):**
```bash
bash ~/.claude/skills/diagnose/scripts/check_app_signatures_highrisk.sh
```

**What to look for:**
- **Valid**: Authority shows legitimate developer name (e.g., "Developer ID Application: Adobe Inc.")
- **Suspicious**: Authority shows "Apple Development" or ad-hoc signature
- **CRITICAL**: "code signature invalid", "unsigned", or missing TeamIdentifier
- **CRITICAL**: Authority doesn't match expected developer (e.g., Adobe app not signed by Adobe)

**Known legitimate developers:** See `~/.claude/skills/diagnose/references/security_output_format.md` for the full reference table.

#### 7.7 Network Exfiltration Indicators
```bash
bash ~/.claude/skills/diagnose/scripts/check_network_exfiltration.sh
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

### 8. Browser Security (Safari & Chrome)
```bash
bash ~/.claude/skills/diagnose/scripts/check_browser_security.sh
```

**Present:**
- Fraudulent site warnings: Enabled/Disabled
- Do Not Track: Enabled/Disabled
- Extensions installed: List
- Privacy score: Good/Review needed

### 9. File Permissions & Integrity
```bash
bash ~/.claude/skills/diagnose/scripts/check_file_integrity.sh
```

**Present:**
- Sudoers permissions: Secure/Insecure
- Hosts file: Clean/Modified (list entries)
- World-writable files: Count
- File integrity: Good/Issues found

---

## Backup & Update Status (Full mode only)

```bash
bash ~/.claude/skills/diagnose/scripts/check_backups.sh
```

**Present:**
- Time Machine: Last backup date/time
- Backup status: Running/Idle/Not configured
- Software updates: Count pending
- FileVault: Enabled/Disabled
- Recommendations for data protection

---

## Output Formatting

- **Full mode:** Format per `~/.claude/skills/diagnose/references/full_output_format.md`.
- **Security mode:** Format per `~/.claude/skills/diagnose/references/security_output_format.md`.
- **Hardware / Network modes:** Use the relevant subsections from the full output format.

---

## Post-Report

After presenting the report, ask:
"Would you like me to help fix any of these issues? Specify the numbers (e.g., 1,3) or 'all safe' to run all safe actions."

**Important:** Be proactive about security. If firewall is disabled or Time Machine not configured, emphasize these in recommendations.

## Safety Rules
- Never kill processes without user confirmation
- Mark Claude sessions as PROTECTED unless user explicitly wants to close them
- Mark system processes (WindowServer, kernel_task, etc.) as PROTECTED
- Always offer graceful quit (osascript) before force kill
- Warn before any action that would terminate user work
- Never disable security features without explicit user confirmation
- Always warn before making security configuration changes
- Explain the impact of each recommended change
- Prioritize data protection over convenience
- Mark any findings that could indicate compromise as CRITICAL

## Troubleshooting

- **"Operation not permitted" on battery or SMART checks**: Some queries require elevated permissions. Skip the failing check and note it in the report.
- **"Operation not permitted" on security database queries**: TCC restrictions may prevent access. Skip the check and note it.
- **Thermal/GPU scripts return empty on non-Apple-Silicon Macs**: Detect architecture first. Skip unsupported checks with "Not available on this hardware."
- **App signature check times out**: Use the quick scan script instead of the full verbose scan.
- **False positives in infostealer detection**: Cross-reference flagged items against known developer tools. Ask the user to verify uncertain items.
- **Individual script fails**: Skip that check, note as "SKIPPED: [reason]", and continue with remaining checks.

# Diagnose Full Output Format

Format the output as:

#### System Overview
- **Chip:** [Chip model]
- **Cores:** X cores
- **Load:** X.XX / Y cores (healthy/warning/critical)
- **RAM:** X GB / Y GB (Z%)
- **Swap:** X GB used (healthy/warning/critical)
- **Uptime:** X days
- **Disk:** X GB / Y GB (Z% used)

#### Battery Health (if available)
Present the battery findings table from section 5, including:
- Actual vs Nominal capacity explanation
- Cycle count status
- Cell health assessment
- Temperature
- Key finding summary: "Battery shows textbook aging" or "Immediate attention needed"

#### GPU & Graphics
- **GPU:** Model name
- **VRAM:** X GB
- **GPU Usage:** X% (if available)
- **Displays:** Resolution and count
- **Top GPU consumers:** Process list

#### Disk Health
- **SMART Status:** Verified/Failing
- **SSD Wear:** X% (if available)
- **Temperature:** X°C
- **Errors (24h):** N
- **Health:** Excellent/Good/Warning/Critical

#### Network Quality
- **Interface:** en0/en1
- **WiFi Signal:** -XX dBm (Excellent/Good/Fair/Poor)
- **WiFi Speed:** Current/Max Mbps
- **Packet Loss:** X packets
- **Active Connections:** N

#### Security Posture Summary
**Overall Risk Level:** LOW/MEDIUM/HIGH/CRITICAL

Quick metrics:
- Firewall: pass/fail
- FileVault: pass/fail
- Security updates: pass/warning/fail
- Remote access: Secure / Review / Exposed

#### Network Security
| Check | Status | Details |
|-------|--------|---------|
| Firewall | Enabled/Disabled | Block all: Y/N, Stealth: Y/N |
| Open Ports | N ports | List critical ones |
| DNS | Configured | Servers: X.X.X.X |
| VPN | Active/Inactive | Connection details |
| Proxy | None/Configured | Details if configured |

#### Encryption & Protection
| Check | Status | Risk |
|-------|--------|------|
| FileVault | On/Off | CRITICAL if off |
| Firmware Password | Set/Unknown/Not set | HIGH if not set |
| Screen Lock | Enabled/Disabled | MEDIUM if disabled |
| Lock Delay | Immediate/X sec | LOW if >5sec |

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

#### Updates & Patches
| Check | Status |
|-------|--------|
| Pending Updates | N updates |
| Last Check | Date/time |
| Auto Check | Enabled/Disabled |
| Auto Install | Enabled/Disabled |
| Gatekeeper | Enabled/Disabled |

#### Suspicious Activity
| Category | Count | Details |
|----------|-------|---------|
| Recent Crashes | N | App names |
| Kernel Panics | N | Dates |
| Root Processes | N suspicious | Process names |
| Hidden Files | N | Locations |
| Login Items | N | Names |
| Kernel Extensions | N non-Apple | Names |

#### Infostealer Detection
| Check | Status | Risk |
|-------|--------|------|
| LaunchAgents/Daemons | Clean/Suspicious entries | Details |
| Hidden Directories | None/Found | Locations |
| Browser Credential Access | Normal/Recent suspicious | Details |
| Keychain Access | Normal/Anomalies detected | Details |
| Known Malware Paths | Clean/IOCs found | CRITICAL if found |
| Suspicious Network | Normal/Exfiltration indicators | IPs/Ports |

#### Application Signature Audit
**Total Apps Scanned:** N applications

| Status | Count | Apps |
|--------|-------|------|
| Valid (Developer ID) | N | List legitimate apps |
| Valid (Apple) | N | System apps |
| Ad-hoc/Development | N | Apps needing review |
| Unsigned/Invalid | N | **CRITICAL** - List apps |

#### Browser Security
| Check | Status |
|-------|--------|
| Fraudulent Site Warnings | Enabled/Disabled |
| Do Not Track | Enabled/Disabled |
| Extensions | N installed |
| Privacy Score | Good/Review |

#### File Integrity
| Check | Status |
|-------|--------|
| Sudoers Permissions | Secure/Insecure |
| Hosts File | Clean/Modified |
| World-Writable Files | N found |

#### Backup & Updates
- **Time Machine:** Last backup date or "Not configured"
- **Backup Status:** Running/Idle/Not configured
- **Software Updates:** N pending
- **Recommendations:** Backup warnings if needed

#### Thermal & Performance
- **Thermal Status:** Normal/Warning/Critical
- **CPU Throttling:** Yes/No
- **Disk I/O:** Read/Write performance

#### Problems Found
Table with: Category | Count | Impact | Safety to Kill

#### Top Resource Consumers
**CPU (Top 10):**
[Table showing PID, %CPU, Command]

**Memory (Top 10):**
[Table showing MB used, Command]

**Network (Top 5):**
[Processes using network]

#### Background Process Summary
- **User launch agents:** N active
- **High-impact processes:** [List if any]

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

#### Key Findings
Summarize the most important insights:
- "System is healthy" or "X issues found requiring attention"
- Battery: "72.8% capacity, replace when convenient" (if degraded)
- Performance: "No bottlenecks detected" or "High memory pressure from X"
- Security: "Well protected" or "Enable firewall and FileVault"
- Storage: "Can reclaim X GB by clearing caches"

---
name: diagnose-all
description: "Run comprehensive system diagnostics including CPU, memory, battery health, GPU, disk health (SMART), network quality, security audit, cleanup opportunities, and backup status. Use when user says 'diagnose my system', 'system health check', 'is my Mac healthy', 'check performance', or 'full diagnostics'."
allowed-tools: Bash
---

# System Diagnostics Skill

Run a comprehensive system diagnostic to identify resource bottlenecks, battery degradation, stuck processes, thermal issues, and provide actionable recommendations.

## Instructions

When invoked, run the following diagnostic steps and present results in a clear table format:

### 1. Gather System Info
```bash
bash ~/.claude/skills/diagnose-all/scripts/system_info.sh
```

### 2. Check CPU Usage
```bash
bash ~/.claude/skills/diagnose-all/scripts/check_cpu.sh
```

### 3. Check Memory Usage
```bash
bash ~/.claude/skills/diagnose-all/scripts/check_memory.sh
```

### 4. Check for Problems
```bash
bash ~/.claude/skills/diagnose-all/scripts/check_problems.sh
```

### 5. Battery Health (macOS only)
```bash
bash ~/.claude/skills/diagnose-all/scripts/check_battery.sh
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
bash ~/.claude/skills/diagnose-all/scripts/check_disk_io.sh
```

**Present:**
- Disk usage: X GB / Y GB (Z% used)
- I/O load: Read/Write MB/s
- Processes in disk wait state (if any)

### 7. Network Activity
```bash
bash ~/.claude/skills/diagnose-all/scripts/check_network.sh
```

**Present:**
- Active connections: N
- Top network-using processes

### 8. Thermal Status
```bash
bash ~/.claude/skills/diagnose-all/scripts/check_thermal.sh
```

**Present:**
- Thermal pressure status
- CPU throttling: Yes/No

### 9. Background Process Audit
```bash
bash ~/.claude/skills/diagnose-all/scripts/audit_background.sh
```

**Present:**
- User launch agents: N active
- High-impact background processes

### 10. GPU & Graphics Performance
```bash
bash ~/.claude/skills/diagnose-all/scripts/check_gpu.sh
```

**Present:**
- GPU model and VRAM
- GPU utilization % (if available)
- GPU memory used/free
- Top GPU consumers
- Connected displays

### 11. Disk Health (SMART Status)
```bash
bash ~/.claude/skills/diagnose-all/scripts/check_disk_health.sh
```

**Present:**
- SMART status: Verified/Failing
- SSD wear level (if available)
- Drive temperature
- Disk errors (last 24h)
- Estimated health: Excellent/Good/Warning/Critical

### 12. Network Throughput & Quality
```bash
bash ~/.claude/skills/diagnose-all/scripts/check_network_quality.sh
```

**Present:**
- Network interface: Active interface name
- WiFi signal: -XX dBm (Excellent/Good/Fair/Poor)
- WiFi speed: Current/Max Mbps
- Packet loss/errors: Count
- Top bandwidth consumers

### 13. Security Audit
```bash
bash ~/.claude/skills/diagnose-all/scripts/audit_security.sh
```

**Present:**
- Firewall: Enabled/Disabled
- Open ports: List with process names
- VPN: Active/Inactive
- Recent crashes: Count and app names
- Kernel panics: Count (last 7 days)
- Security score: Good/Needs Attention

### 14. Cleanup Opportunities
```bash
bash ~/.claude/skills/diagnose-all/scripts/check_cleanup_opps.sh
```

**Present:**
- Cache size: User + System
- Logs size: Total
- Trash size: Can be emptied
- Downloads folder: Size
- Large files: Top 10 (>100MB)
- Total reclaimable space: Estimate

### 15. Backup & Update Status
```bash
bash ~/.claude/skills/diagnose-all/scripts/check_backups.sh
```

**Present:**
- Time Machine: Last backup date/time
- Backup status: Running/Idle/Not configured
- Software updates: Count pending
- FileVault: Enabled/Disabled
- Recommendations for data protection

### 16. Present Results

Format the output as:

#### 📊 System Overview
- **Chip:** [Chip model]
- **Cores:** X cores
- **Load:** X.XX / Y cores (healthy/warning/critical)
- **RAM:** X GB / Y GB (Z%)
- **Swap:** X GB used (healthy/warning/critical)
- **Uptime:** X days
- **Disk:** X GB / Y GB (Z% used)

#### 🔋 Battery Health (if available)
Present the battery findings table from section 5, including:
- Actual vs Nominal capacity explanation
- Cycle count status
- Cell health assessment
- Temperature
- Key finding summary: "Battery shows textbook aging" or "Immediate attention needed"

#### 🎮 GPU & Graphics
- **GPU:** Model name
- **VRAM:** X GB
- **GPU Usage:** X% (if available)
- **Displays:** Resolution and count
- **Top GPU consumers:** Process list

#### 💾 Disk Health
- **SMART Status:** Verified/Failing
- **SSD Wear:** X% (if available)
- **Temperature:** X°C
- **Errors (24h):** N
- **Health:** Excellent/Good/Warning/Critical

#### 🌐 Network Quality
- **Interface:** en0/en1
- **WiFi Signal:** -XX dBm (Excellent/Good/Fair/Poor)
- **WiFi Speed:** Current/Max Mbps
- **Packet Loss:** X packets
- **Active Connections:** N

#### 🔒 Security Status
- **Firewall:** Enabled/Disabled
- **FileVault:** Enabled/Disabled
- **Open Ports:** List (port:process)
- **VPN:** Active/Inactive
- **Recent Crashes:** N (app names)
- **Kernel Panics:** N
- **Security Score:** Good/Needs Attention

#### 🧹 Cleanup Opportunities
- **User Caches:** X GB
- **System Caches:** X GB (if available)
- **Logs:** X GB
- **Trash:** X GB
- **Downloads:** X GB
- **Total Reclaimable:** ~X GB

#### ☁️ Backup & Updates
- **Time Machine:** Last backup date or "Not configured"
- **Backup Status:** Running/Idle/Not configured
- **Software Updates:** N pending
- **Recommendations:** Backup warnings if needed

#### 🌡️ Thermal & Performance
- **Thermal Status:** Normal/Warning/Critical
- **CPU Throttling:** Yes/No
- **Disk I/O:** Read/Write performance

#### ⚠️ Problems Found
Table with: Category | Count | Impact | Safety to Kill

#### 🔝 Top Resource Consumers
**CPU (Top 10):**
[Table showing PID, %CPU, Command]

**Memory (Top 10):**
[Table showing MB used, Command]

**Network (Top 5):**
[Processes using network]

#### 📋 Background Process Summary
- **User launch agents:** N active
- **High-impact processes:** [List if any]

#### ✅ Recommended Actions
Numbered list, safest actions first:
1. Actions marked SAFE (e.g., "Quit idle Chrome tabs", "Empty trash (X GB)")
2. Actions that need confirmation (e.g., "Kill stuck process PID 1234")
3. Security actions (e.g., "Enable firewall", "Configure Time Machine")
4. Long-term recommendations (e.g., "Battery replacement suggested")

#### 💡 Key Findings
Summarize the most important insights:
- "System is healthy" or "X issues found requiring attention"
- Battery: "72.8% capacity, replace when convenient" (if degraded)
- Performance: "No bottlenecks detected" or "High memory pressure from X"
- Security: "Well protected" or "Enable firewall and FileVault"
- Storage: "Can reclaim X GB by clearing caches"

### 17. Offer to Help
After presenting the report, ask:
"Would you like me to proceed with any of these actions? Specify the numbers (e.g., 1,3) or 'all safe' to run all safe actions."

**Important:** Be proactive about security. If firewall is disabled or Time Machine not configured, emphasize these in recommendations.

## Safety Rules
- Never kill processes without user confirmation
- Mark Claude sessions as PROTECTED unless user explicitly wants to close them
- Mark system processes (WindowServer, kernel_task, etc.) as PROTECTED
- Always offer graceful quit (osascript) before force kill
- Warn before any action that would terminate user work

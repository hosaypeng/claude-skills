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

Format output per `references/output_format.md`.

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

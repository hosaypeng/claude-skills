# Diagnose-All Output Format

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

#### Security Status
- **Firewall:** Enabled/Disabled
- **FileVault:** Enabled/Disabled
- **Open Ports:** List (port:process)
- **VPN:** Active/Inactive
- **Recent Crashes:** N (app names)
- **Kernel Panics:** N
- **Security Score:** Good/Needs Attention

#### Cleanup Opportunities
- **User Caches:** X GB
- **System Caches:** X GB (if available)
- **Logs:** X GB
- **Trash:** X GB
- **Downloads:** X GB
- **Total Reclaimable:** ~X GB

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

#### Recommended Actions
Numbered list, safest actions first:
1. Actions marked SAFE (e.g., "Quit idle Chrome tabs", "Empty trash (X GB)")
2. Actions that need confirmation (e.g., "Kill stuck process PID 1234")
3. Security actions (e.g., "Enable firewall", "Configure Time Machine")
4. Long-term recommendations (e.g., "Battery replacement suggested")

#### Key Findings
Summarize the most important insights:
- "System is healthy" or "X issues found requiring attention"
- Battery: "72.8% capacity, replace when convenient" (if degraded)
- Performance: "No bottlenecks detected" or "High memory pressure from X"
- Security: "Well protected" or "Enable firewall and FileVault"
- Storage: "Can reclaim X GB by clearing caches"

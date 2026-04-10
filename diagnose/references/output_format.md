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
- Network Security: /15
- Encryption: /15
- Authentication: /15
- Updates: /15
- Infostealer Detection: /20
- Threat Level: /10
- Privacy: /10

## Recommendations Format
Priority-ordered: CRITICAL → HIGH → MEDIUM → LOW. Each with specific action.

## If IOCs Found
1. Disconnect from network
2. Full Malwarebytes scan
3. Change all passwords from clean device
4. Check financial accounts
5. Consider full wipe if active compromise confirmed

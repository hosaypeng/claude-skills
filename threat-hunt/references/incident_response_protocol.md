# Incident Response Protocol

**CRITICAL FINDING DETECTED.** Follow these steps immediately:

1. **Disconnect from network** — Disable Wi-Fi and unplug Ethernet. This prevents data exfiltration and C2 communication.

2. **Do NOT power off** — Volatile evidence (memory, running processes) is lost on shutdown. Leave the machine running but isolated.

3. **From a CLEAN device** (phone, another computer):
   - Change all passwords (email, banking, crypto exchanges, cloud accounts)
   - Revoke API keys and rotate secrets
   - Enable 2FA on all accounts if not already enabled
   - Check financial accounts for unauthorized transactions

4. **Forensic preservation** — If you suspect nation-state targeting:
   - Run MVT against iOS backups: `pip3 install mvt && mvt-ios check-backup`
   - Consider engaging a professional incident response firm
   - Contact Citizen Lab (citizenlab.ca) if you are a journalist, activist, or human rights defender
   - File an Apple threat notification report if you received one

5. **Recovery** — After evidence is preserved:
   - Full Malwarebytes scan from Safe Mode
   - If active compromise confirmed: full disk wipe and clean OS reinstall
   - Restore from a backup dated BEFORE the suspected compromise date
   - Re-enable FileVault, Lockdown Mode, and all hardening measures

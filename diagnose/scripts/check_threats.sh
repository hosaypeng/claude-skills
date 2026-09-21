#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Suspicious Activity & Threats ==="

echo "--- Recent Crashes ---"
# Crash reports are .ips files (the .crash format is gone), and a fallback hung off a
# pipe never fires because the pipe's exit status is awk's. Test the result instead.
crashes=$(ls -t ~/Library/Logs/DiagnosticReports/*.ips 2>/dev/null | head -5)
if [ -n "$crashes" ]; then
  echo "$crashes" | while IFS= read -r f; do
    echo "$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null) $(basename "$f")"
  done
else
  echo "No recent crashes"
fi

echo "--- Kernel Panics ---"
panics=$(ls -t /Library/Logs/DiagnosticReports/*panic* 2>/dev/null | head -3)
[ -n "$panics" ] && echo "$panics" || echo "No kernel panics"

echo "--- Suspicious Root Processes ---"
ps aux | awk '$1 == "root" && $3 > 1.0 {print $11}' | grep -v "kernel_task\|WindowServer\|launchd\|coreaudiod" | head -10 || echo "None"

echo "--- Hidden Files in Exploit Locations ---"
echo "In /tmp:"
hidden_tmp=$(find -H /tmp -name ".*" -type f 2>/dev/null | head -10)   # -H: /tmp is a symlink
[ -n "$hidden_tmp" ] && echo "$hidden_tmp" || echo "None"
echo "In ~/.ssh:"
hidden_ssh=$(find ~/.ssh -name ".*" -type f 2>/dev/null | head -5)
[ -n "$hidden_ssh" ] && echo "$hidden_ssh" || echo "None"

echo "--- Login Items ---"
osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null || echo "Could not retrieve login items"

echo "--- Third-Party Kernel Extensions ---"
# kextstat is now a shim that prints "Executing: /usr/bin/kmutil showloaded" and a
# "No variant specified" notice, both of which survived the com.apple filter and landed in
# a scored category. Call kmutil directly and drop its header and notices.
kexts=$(kmutil showloaded --no-kernel-components 2>/dev/null \
  | grep -vE "^Index|com\.apple|^No variant|^Executing" | head -10)
[ -n "$kexts" ] && echo "$kexts" || echo "None"

exit 0

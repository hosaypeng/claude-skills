#!/bin/bash
set -e

echo "=== CPU Usage ==="

# Top 20 CPU consumers
ps aux -r | head -20

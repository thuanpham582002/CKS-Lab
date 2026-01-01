#!/bin/bash
# Prepare CKS Lab VM for export by removing cloud-init state
# This allows cloud-init to re-run when the VM is imported on another machine

set -e

echo "=== Preparing VM for export ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo"
  exit 1
fi

echo "Step 1: Removing cloud-init instance state..."
rm -rf /var/lib/cloud/instances
rm -rf /var/lib/cloud/instance
rm -f /var/lib/cloud/instance/*.disabled

echo "Step 2: Cleaning cloud-init logs..."
rm -f /var/log/cloud-init-output.log
rm -f /var/log/cloud-init.log

echo "Step 3: Creating locale-check skip marker..."
mkdir -p /var/lib/cloud/instance
touch /var/lib/cloud/instance/locale-check.skip

echo "Step 4: Clearing machine-id (will be regenerated on next boot)..."
rm -f /etc/machine-id
touch /etc/machine-id

echo "Step 5: Cleaning SSH host keys (will be regenerated on next boot)..."
rm -f /etc/ssh/ssh_host_*

echo "Step 6: Cleaning bash history..."
rm -f ~/.bash_history
rm -f /root/.bash_history
rm -f /home/*/.bash_history

echo "Step 7: Cleaning temporary files..."
rm -rf /tmp/*
rm -rf /var/tmp/*

echo "=== VM preparation complete ==="
echo ""
echo "Next steps:"
echo "1. Exit the VM: exit"
echo "2. From macOS host: orbctl export cks-lab ~/cks-lab.tar.zst"
echo ""
echo "After importing on another machine:"
echo "- Cloud-init will re-run automatically"
echo "- New SSH host keys will be generated"
echo "- New machine-id will be assigned"

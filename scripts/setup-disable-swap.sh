#!/bin/bash
# Setup script to disable swap in OrbStack for Kubernetes
# Run this script INSIDE the OrbStack VM with sudo

set -e

echo "=== Setting up swap disable service for Kubernetes ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo"
  exit 1
fi

# Step 1: Create disable swap script
echo "Creating /usr/local/bin/disable-swap.sh..."
cat > /usr/local/bin/disable-swap.sh << 'EOF'
#!/bin/bash
# Disable all swap devices for Kubernetes
logger "Disabling swap for Kubernetes..."
swapoff -a
if [ $? -eq 0 ]; then
  logger "Swap disabled successfully"
else
  logger "Failed to disable swap"
  exit 1
fi
EOF

chmod +x /usr/local/bin/disable-swap.sh
echo "✓ Script created and made executable"

# Step 2: Create systemd service
echo "Creating /etc/systemd/system/disable-swap.service..."
cat > /etc/systemd/system/disable-swap.service << 'EOF'
[Unit]
Description=Disable swap for Kubernetes
After=multi-user.target
Before=kubelet.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/disable-swap.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "✓ Systemd service file created"

# Step 3: Reload systemd and enable service
echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling disable-swap.service..."
systemctl enable disable-swap.service

echo "✓ Service enabled"

# Step 4: Start service immediately
echo "Starting disable-swap.service..."
systemctl start disable-swap.service

echo "✓ Service started"

# Step 5: Verification
echo ""
echo "=== Verification ==="
echo "Swap status:"
free -h

echo ""
echo "Swap devices:"
swapon --show || echo "No swap devices (good!)"

echo ""
echo "Service status:"
systemctl status disable-swap.service --no-pager

echo ""
echo "=== Setup Complete ==="
echo "✓ Swap has been disabled"
echo "✓ Service will auto-disable swap on every boot"
echo ""
echo "To verify after reboot:"
echo "  1. Run: sudo reboot"
echo "  2. After reboot, run: free -h"
echo "     Swap should show 0B"

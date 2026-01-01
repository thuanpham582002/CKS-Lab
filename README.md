# CKS Exam Preparation Lab

This repository contains cloud-init configurations and Kubernetes manifests for setting up a secure Kubernetes 1.32.2 cluster optimized for Certified Kubernetes Security Specialist (CKS) exam preparation.

## Overview

The CKS Lab provides a comprehensive security-hardened Kubernetes environment with:
- Single-node Kubernetes cluster with security hardening
- Pre-installed security tools (Falco, kube-bench, Trivy)
- 10+ practice scenarios covering common security vulnerabilities
- Network policies and security configurations
- Automated validation and setup scripts

## Quick Start

### Prerequisites

**Option 1: AWS EC2**
- AWS EC2 instance (minimum t3.medium: 2 vCPU, 4GB RAM)
- Ubuntu 22.04 LTS AMI
- Your SSH public key

**Option 2: OrbStack (macOS)**
- [OrbStack](https://orbstack.dev/) installed
- macOS machine with 16GB+ RAM recommended
- OrbStack configured with adequate resources (CPU: 4+, RAM: 16GB)

### Choosing the Right Cloud-Init File

This lab provides platform-specific cloud-init configurations:

**For OrbStack (macOS):**
- **`cloud-init/orbstack/arm64.yaml`**: For **ARM64** systems
  - Apple Silicon (M1/M2/M3)
  - Other ARM64 platforms

- **`cloud-init/orbstack/amd64.yaml`**: For **AMD64/Intel 64-bit** systems
  - Intel Mac

**For AWS EC2:**
- **`cloud-init/aws/user-data.yaml`**: Template for AWS EC2
  - Supports both ARM64 and AMD64 instances
  - Customize before deployment

**Check your system architecture:**
```bash
uname -m
# Output: x86_64  → use amd64.yaml
# Output: aarch64 → use arm64.yaml
```

### Launch the CKS Lab VM

#### Option 1: AWS EC2 Instance

1. **Launch AWS EC2 Instance**:
   ```bash
   # Replace with your SSH public key
   export SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7..."
   export ENCRYPTION_SECRET="$(openssl rand -base64 32)"

   # Launch EC2 instance with cloud-init
   aws ec2 run-instances \
     --image-id ami-0c02fb55956c7d316 \
     --instance-type t3.medium \
     --key-name your-key-pair \
     --security-group-ids sg-xxxxxxxxxx \
     --subnet-id subnet-xxxxxxxxxx \
     --user-data file://cloud-init/aws/user-data.yaml \
     --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cks-lab}]'
   ```

2. **Customize Cloud-Init** (Optional):
   Before launching, update these variables in `cloud-init/aws/user-data.yaml`:
   - `${ssh_public_key}`: Add your SSH public key
   - `${encryption_secret}`: Generate with `openssl rand -base64 32`

3. **Connect to the Instance**:
   ```bash
   ssh -i your-key-pair.pem cks-user@<instance-public-ip>
   ```

4. **Verify Installation**:
   ```bash
   # Check cluster status
   kubectl get nodes
   kubectl get pods --all-namespaces

   # Run validation script
   /Users/noroom113/selfproject/cks-lab/scripts/validate-cluster.sh
   ```

#### Option 2: OrbStack (macOS Local)

OrbStack provides a fast, lightweight way to run the CKS Lab locally on macOS.

1. **Configure OrbStack Resources** (optional, if needed):
   ```bash
   # Set CPU and memory limits
   orb config set cpu 8
   orb config set memory_mib 16384  # 16GB
   ```

2. **Create OrbStack VM with Cloud-Init**:
   ```bash
   # Navigate to cks-lab directory
   cd /path/to/cks-lab

   # Delete existing VM (if any)
   orbctl delete cks-lab

   # Create new VM with cloud-init
   # For Apple Silicon (M1/M2/M3):
   orbctl create -c ./cloud-init/orbstack/arm64.yaml ubuntu:22.04 cks-lab

   # For Intel Mac:
   orbctl create -c ./cloud-init/orbstack/amd64.yaml ubuntu:22.04 cks-lab
   ```

3. **Connect to the VM**:
   ```bash
   # SSH into the VM
   orbctl ssh cks-lab

   # Or use direct SSH
   ssh cks-lab
   ```

4. **Verify Installation**:
   ```bash
   # Inside the VM, check cluster status
   kubectl get nodes
   kubectl get pods --all-namespaces

   # Verify swap is disabled
   free -h                    # Swap should be 0B
   systemctl status disable-swap.service  # Should be active

   # Run validation script
   ./scripts/validate-cluster.sh
   ```

**OrbStack-Specific Notes**:
- The cloud-init configuration includes a systemd service (`disable-swap.service`) that automatically disables swap on boot
- Swap must be disabled for Kubernetes to work properly
- The VM will automatically reboot after cloud-init completes
- First boot may take 5-10 minutes for Kubernetes installation

## Lab Structure

```
cks-lab/
├── cloud-init/
│   ├── orbstack/
│   │   ├── arm64.yaml         # Configured for ARM64 (Apple Silicon)
│   │   └── amd64.yaml         # Configured for AMD64 (Intel Mac)
│   └── aws/
│       └── user-data.yaml     # Template for AWS EC2
├── configs/
│   ├── containerd-config.toml  # Container runtime security config
│   ├── kubeadm-config.yaml     # Cluster initialization config
│   └── falco-rules.yaml        # Custom Falco security rules
├── manifests/
│   ├── security/               # Security tool deployments
│   │   ├── falco-deployment.yaml
│   │   └── network-policies.yaml
│   └── practice/               # CKS practice scenarios
│       └── cks-scenarios.yaml
├── scripts/
│   ├── validate-cluster.sh     # Security validation script
│   ├── setup-scenarios.sh      # Practice scenario setup
│   ├── setup-disable-swap.sh   # Disable swap for Kubernetes (manual)
│   └── prepare-for-export.sh   # Prepare VM for export (cleanup)
└── README.md                   # This file
```

## Security Features

### System Hardening
- SSH hardening (key-based auth only)
- UFW firewall configuration
- Kernel security parameters
- AppArmor and seccomp profiles

### Kubernetes Security
- CIS benchmark compliance
- API server hardening (audit logging, anonymous auth disabled)
- Pod Security Standards enforcement
- Network policies with Calico CNI
- RBAC with least privileges

### Security Tools
- **Falco**: Runtime threat detection with 20+ custom rules
- **kube-bench**: CIS Kubernetes benchmark assessment
- **Trivy**: Container and filesystem vulnerability scanning

## Practice Scenarios

The lab includes 10 vulnerable workloads for hands-on security practice:

1. **Privileged Container** - Pod with privileged access
2. **Root Container** - Pod running as root user
3. **Host Filesystem** - Pod accessing host filesystem
4. **All Capabilities** - Pod with all Linux capabilities
5. **Docker Socket** - Pod with Docker socket access
6. **Sensitive Paths** - Pod mounting sensitive host paths
7. **Service Account** - Pod with excessive RBAC permissions
8. **Untrusted Image** - Pod using untrusted registry image
9. **Host Network** - Pod using host network namespaces
10. **No Security Context** - Pod lacking security configuration

### Setting Up Practice Scenarios

```bash
# Set up all practice scenarios
./scripts/setup-scenarios.sh setup

# Deploy only scenarios (if tools already installed)
./scripts/setup-scenarios.sh deploy

# Check security issues in scenarios
./scripts/setup-scenarios.sh check

# View current status
./scripts/setup-scenarios.sh status

# Clean up scenarios
./scripts/setup-scenarios.sh cleanup
```

### Example: Fixing a Privileged Container

```bash
# Find privileged pods
kubectl get pods -n cks-practice -l security-issue=privileged

# Examine the pod configuration
kubectl describe pod privileged-pod-vulnerable -n cks-practice

# Edit the pod to remove privileged access
kubectl edit pod privileged-pod-vulnerable -n cks-practice
# Change: privileged: true → privileged: false

# Verify the fix
kubectl get pod privileged-pod-vulnerable -n cks-practice -o yaml | grep privileged
```

## Validation and Monitoring

### Security Validation

Run the comprehensive security validation script:

```bash
./scripts/validate-cluster.sh
```

This script checks:
- CIS Kubernetes benchmark compliance (kube-bench)
- Privileged pods and containers
- RBAC configurations
- Network policies
- Pod Security Standards
- Vulnerable images (with Trivy)

### Real-time Monitoring

Monitor security events with Falco:

```bash
# View Falco logs
kubectl logs -n security-tools -l app.kubernetes.io/name=falco -f

# Check Falco events
kubectl get events -n security-tools --field-selector involvedObject.kind=Pod
```

### Network Policy Testing

```bash
# Test network policies in network-security namespace
kubectl exec -it deployment/frontend -n network-security -- curl http://webapp-service.network-security

# Test egress restrictions
kubectl exec -it deployment/high-security-app -n network-security -- curl -m 5 http://example.com
```

## CKS Exam Practice Areas

### 1. Cluster Setup
- Hardening cluster components
- Configuring network policies
- Setting up admission controllers

### 2. System Hardening
- Minimizing container image footprint
- Securing node access
- Kernel hardening

### 3. Minimize Microservice Vulnerabilities
- Security contexts for pods and containers
- RBAC and service accounts
- Network policies

### 4. Supply Chain Security
- Image scanning and signing
- Admission controllers for image policies
- Runtime security

### 5. Monitoring, Logging, and Runtime Security
- Audit logging configuration
- Runtime threat detection (Falco)
- Forensics and incident response

## Troubleshooting

### Common Issues

1. **Swap enabled (Kubernetes fails to start)**:
   ```bash
   # Check swap status
   free -h
   swapon --show

   # For OrbStack: Check systemd service
   systemctl status disable-swap.service

   # Immediately disable swap
   sudo swapoff -a

   # For OrbStack: Ensure service is enabled
   sudo systemctl enable disable-swap.service
   sudo systemctl start disable-swap.service
   ```

2. **Pods stuck in ContainerCreating**:
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   # Check if CNI is ready: kubectl get pods -n kube-system
   ```

2. **Falco not working**:
   ```bash
   kubectl logs -n security-tools -l app.kubernetes.io/name=falco
   # Ensure kernel modules are loaded
   lsmod | grep falco
   ```

3. **Network policies not working**:
   ```bash
   kubectl get pods -n kube-system -l k8s-app=calico-node
   # Verify Calico is running
   ```

4. **Cloud-init fails on first boot**:
   ```bash
   # Check cloud-init logs
   sudo tail -f /var/log/cloud-init-output.log

   # Common fixes:
   # - Ensure user-data-configured.yaml is valid YAML
   # - Check for sufficient disk space: df -h
   # - Verify network connectivity: ping -c 3 8.8.8.8
   ```

### Reset the Environment

#### AWS EC2
```bash
# Complete reset
./scripts/setup-scenarios.sh cleanup
./scripts/setup-scenarios.sh setup

# Reset Kubernetes cluster (if needed)
sudo kubeadm reset
sudo rm -rf /etc/cni/net.d
sudo systemctl restart kubelet
```

#### OrbStack
```bash
# Complete reset (from macOS host)
orbctl delete cks-lab
# For Apple Silicon:
orbctl create -c ./cloud-init/orbstack/arm64.yaml ubuntu:22.04 cks-lab
# For Intel Mac:
orbctl create -c ./cloud-init/orbstack/amd64.yaml ubuntu:22.04 cks-lab

# Quick cluster reset (from inside VM)
sudo kubeadm reset
sudo rm -rf /etc/cni/net.d
sudo systemctl restart kubelet
```

## AWS Considerations

### Recommended Instance Types
- **Minimum**: t3.medium (2 vCPU, 4GB RAM)
- **Recommended**: t3.large (2 vCPU, 8GB RAM)
- **For production**: m5.large (2 vCPU, 8GB RAM)

### Security Groups
Configure security groups to allow:
- SSH (Port 22) from your IP
- Kubernetes API (Port 6443) from your IP
- Monitoring ports (9090, 3000) from your IP

### Storage
- **Root volume**: Minimum 30GB GP3
- **Additional volume**: 20GB for container images and logs

### IAM Role
The EC2 instance needs an IAM role with:
- EC2 instance permissions
- SSM access (for AWS Systems Manager)
- CloudWatch permissions (for logs)

## OrbStack Considerations

### Resource Allocation
- **Minimum**: 4 vCPU, 8GB RAM
- **Recommended**: 8 vCPU, 16GB RAM
- Configure with: `orb config set cpu 8` and `orb config set memory_mib 16384`

### Common OrbStack Issues

1. **Swap not disabled after reboot**:
   ```bash
   # Check service status
   systemctl status disable-swap.service

   # If not active, manually enable and start
   sudo systemctl enable disable-swap.service
   sudo systemctl start disable-swap.service

   # Verify swap is disabled
   free -h  # Swap should be 0B
   ```

2. **VM creation fails with cloud-init errors**:
   ```bash
   # Check cloud-init logs
   sudo cat /var/log/cloud-init-output.log

   # Re-run cloud-init manually
   sudo cloud-init init
   sudo cloud-init modules
   sudo cloud-init final
   ```

3. **Kubernetes fails to start due to swap**:
   ```bash
   # Immediately disable swap
   sudo swapoff -a

   # Verify kubeadm can proceed
   sudo kubeadm init --ignore-preflight-errors=Swap
   ```

4. **Performance issues with multiple pods**:
   ```bash
   # Increase OrbStack resources
   orb config set cpu 8
   orb config set memory_mib 16384

   # Restart the VM
   orbctl restart cks-lab
   ```

### Network Configuration
OrbStack automatically configures networking:
- Host access: `ssh cks-lab` or `orbctl ssh cks-lab`
- Port forwarding: Services are automatically accessible via OrbStack's networking
- For custom port forwards: `orb config set machines.expose_ports_to_lan true`

### Storage and Persistence
- VM data persists in `~/Library/Application Support/OrbStack/`
- To completely reset: `orbctl delete cks-lab` and recreate
- Backup important data before deleting VM

### Exporting and Importing VMs

**Export VM for backup or sharing:**
```bash
# 1. Prepare VM for export (removes cloud-init state, cleans sensitive data)
orbctl ssh cks-lab
cd /Users/noroom113/selfproject/cks-lab/scripts
sudo bash prepare-for-export.sh
exit

# 2. Export VM to file
orbctl export cks-lab ~/cks-lab-ready.tar.zst
```

**Import VM on another machine:**
```bash
# Import from exported file
orbctl import cks-lab ~/cks-lab-ready.tar.zst

# Start the VM
orbctl start cks-lab

# SSH in (cloud-init will NOT re-run - VM is ready to use)
orbctl ssh cks-lab
kubectl get nodes
```

**Important notes:**
- Exported VM includes full Kubernetes cluster (no need to re-run cloud-init)
- `prepare-for-export.sh` cleans: SSH keys, machine-id, logs, temp files
- Cloud-init state is removed so it doesn't interfere on new machine
- First boot on imported VM will regenerate SSH host keys and machine-id

## Contributing

To add new practice scenarios or security rules:

1. Add new pods to `manifests/practice/cks-scenarios.yaml`
2. Add corresponding network policies to `manifests/security/network-policies.yaml`
3. Add Falco rules to `configs/falco-rules.yaml`
4. Update validation checks in `scripts/validate-cluster.sh`

## License

This project is for educational purposes for CKS exam preparation. Use responsibly and only in authorized environments.

## References

- [CKS Exam Curriculum](https://www.cncf.io/certification/cks/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [Falco Documentation](https://falco.org/docs/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
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

- AWS EC2 instance (minimum t3.medium: 2 vCPU, 4GB RAM)
- Ubuntu 22.04 LTS AMI
- Your SSH public key

### Launch the CKS Lab VM

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
     --user-data file://cloud-init/user-data.yaml \
     --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cks-lab}]'
   ```

2. **Customize Cloud-Init** (Optional):
   Before launching, update these variables in `cloud-init/user-data.yaml`:
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

## Lab Structure

```
cks-lab/
├── cloud-init/
│   ├── user-data.yaml          # Main cloud-init configuration
│   └── network-config.yaml     # Network configuration
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
│   └── setup-scenarios.sh      # Practice scenario setup
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

1. **Pods stuck in ContainerCreating**:
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

### Reset the Environment

```bash
# Complete reset
./scripts/setup-scenarios.sh cleanup
./scripts/setup-scenarios.sh setup

# Reset Kubernetes cluster (if needed)
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
#!/bin/bash

# CKS Cluster Validation Script
# This script validates the security posture of the Kubernetes cluster

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "PASS")
            echo -e "${GREEN}[PASS]${NC} $message"
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
    esac
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_status "FAIL" "kubectl is not installed or not in PATH"
        exit 1
    fi
    print_status "PASS" "kubectl is available"
}

# Function to check cluster connectivity
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        print_status "FAIL" "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    print_status "PASS" "Connected to Kubernetes cluster"
}

# Function to run kube-bench checks
run_kube_bench() {
    print_status "INFO" "Running kube-bench CIS benchmark checks..."

    if command -v kube-bench &> /dev/null; then
        # Create results directory
        mkdir -p /tmp/kube-bench-results

        # Run kube-bench and save results
        kube-bench run --json > /tmp/kube-bench-results/kube-bench-$(date +%Y%m%d-%H%M%S).json

        # Run kube-bench and show summary
        kube-bench run --summary | tee /tmp/kube-bench-results/kube-bench-summary-$(date +%Y%m%d-%H%M%S).txt

        print_status "PASS" "kube-bench completed. Results saved to /tmp/kube-bench-results/"
    else
        print_status "WARN" "kube-bench is not installed"
    fi
}

# Function to check for privileged pods
check_privileged_pods() {
    print_status "INFO" "Checking for privileged pods..."

    local privileged_pods=$(kubectl get pods --all-namespaces -o json | \
        jq -r '.items[] | select(.spec.containers[].securityContext.privileged == true) | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null || true)

    if [[ -n "$privileged_pods" ]]; then
        print_status "FAIL" "Found privileged pods:"
        echo "$privileged_pods" | while read -r pod; do
            echo "  - $pod"
        done
    else
        print_status "PASS" "No privileged pods found"
    fi
}

# Function to check for pods running as root
check_root_pods() {
    print_status "INFO" "Checking for pods running as root..."

    local root_pods=$(kubectl get pods --all-namespaces -o json | \
        jq -r '.items[] | select(.spec.containers[].securityContext.runAsUser == 0) | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null || true)

    if [[ -n "$root_pods" ]]; then
        print_status "WARN" "Found pods running as root (may be intentional for system pods):"
        echo "$root_pods" | while read -r pod; do
            echo "  - $pod"
        done
    else
        print_status "PASS" "No pods running as root"
    fi
}

# Function to check for host filesystem mounts
check_host_fs_mounts() {
    print_status "INFO" "Checking for host filesystem mounts..."

    local host_mounts=$(kubectl get pods --all-namespaces -o json | \
        jq -r '.items[] | select(.spec.volumes[].hostPath != null) | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null || true)

    if [[ -n "$host_mounts" ]]; then
        print_status "WARN" "Found pods with host filesystem mounts:"
        echo "$host_mounts" | while read -r pod; do
            echo "  - $pod"
        done
    else
        print_status "PASS" "No pods with host filesystem mounts found"
    fi
}

# Function to check network policies
check_network_policies() {
    print_status "INFO" "Checking network policies..."

    local namespaces=$(kubectl get namespaces -o json | jq -r '.items[] | .metadata.name')

    for ns in $namespaces; do
        local np_count=$(kubectl get networkpolicy -n "$ns" --no-headers 2>/dev/null | wc -l)
        if [[ $np_count -eq 0 ]]; then
            print_status "WARN" "Namespace '$ns' has no network policies"
        else
            print_status "PASS" "Namespace '$ns' has $np_count network policy/policies"
        fi
    done
}

# Function to check Pod Security Standards
check_pss() {
    print_status "INFO" "Checking Pod Security Standards..."

    local namespaces=$(kubectl get namespaces -o json | jq -r '.items[] | .metadata.name')

    for ns in $namespaces; do
        local enforce_label=$(kubectl get namespace "$ns" -o json | jq -r '.metadata.labels["pod-security.kubernetes.io/enforce"] // "not set"')
        local audit_label=$(kubectl get namespace "$ns" -o json | jq -r '.metadata.labels["pod-security.kubernetes.io/audit"] // "not set"')
        local warn_label=$(kubectl get namespace "$ns" -o json | jq -r '.metadata.labels["pod-security.kubernetes.io/warn"] // "not set"')

        if [[ "$enforce_label" != "not set" ]]; then
            print_status "PASS" "Namespace '$ns' has PSS enforce: $enforce_label"
        else
            print_status "WARN" "Namespace '$ns' has no PSS enforce label"
        fi
    done
}

# Function to check RBAC permissions
check_rbac() {
    print_status "INFO" "Checking RBAC configurations..."

    # Check for cluster-admin bindings to non-system users
    local admin_bindings=$(kubectl get clusterrolebinding cluster-admin -o json 2>/dev/null | \
        jq -r '.subjects[]? | select(.name | startswith("system:") | not) | "\(.kind)/\(.name)"' 2>/dev/null || true)

    if [[ -n "$admin_bindings" ]]; then
        print_status "WARN" "Found non-system users with cluster-admin:"
        echo "$admin_bindings" | while read -r binding; do
            echo "  - $binding"
        done
    else
        print_status "PASS" "No non-system users with cluster-admin"
    fi
}

# Function to check API server security settings
check_api_server() {
    print_status "INFO" "Checking API server security settings..."

    # Get API server pod
    local api_server_pod=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$api_server_pod" ]]; then
        # Check if anonymous auth is disabled
        local anonymous_auth=$(kubectl exec -n kube-system "$api_server_pod" -- ps aux | grep kube-apiserver | grep -o "anonymous-auth=[^[:space:]]*" || echo "not found")
        if [[ "$anonymous_auth" =~ "anonymous-auth=false" ]]; then
            print_status "PASS" "Anonymous authentication is disabled"
        else
            print_status "WARN" "Anonymous authentication may be enabled"
        fi

        # Check for audit logging
        local audit_log=$(kubectl exec -n kube-system "$api_server_pod" -- ps aux | grep kube-apiserver | grep -o "audit-log-path=[^[:space:]]*" || echo "not found")
        if [[ "$audit_log" != "not found" ]]; then
            print_status "PASS" "Audit logging is configured"
        else
            print_status "WARN" "Audit logging may not be configured"
        fi
    fi
}

# Function to check security tools status
check_security_tools() {
    print_status "INFO" "Checking security tools status..."

    # Check Falco
    if kubectl get namespace security-tools &> /dev/null; then
        local falco_pods=$(kubectl get pods -n security-tools -l app.kubernetes.io/name=falco --no-headers 2>/dev/null | wc -l)
        if [[ $falco_pods -gt 0 ]]; then
            print_status "PASS" "Falco is running ($falco_pods pods)"
        else
            print_status "WARN" "Falco namespace exists but no pods found"
        fi
    else
        print_status "WARN" "Security tools namespace not found"
    fi
}

# Function to check for vulnerable images
check_vulnerable_images() {
    print_status "INFO" "Checking for vulnerable images (basic check)..."

    if command -v trivy &> /dev/null; then
        # Get images running in the cluster
        local images=$(kubectl get pods --all-namespaces -o json | jq -r '.items[].spec.containers[].image' | sort -u)

        # Create results directory
        mkdir -p /tmp/trivy-results

        for image in $images; do
            print_status "INFO" "Scanning image: $image"
            trivy image --severity HIGH,CRITICAL --format json "$image" > "/tmp/trivy-results/$(echo $image | sed 's/[\/:]/_/g').json" 2>/dev/null || true
        done

        print_status "PASS" "Trivy scans completed. Results saved to /tmp/trivy-results/"
    else
        print_status "WARN" "Trivy is not installed"
    fi
}

# Function to generate summary report
generate_report() {
    local report_file="/tmp/cks-validation-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "CKS Cluster Validation Report"
        echo "Generated on: $(date)"
        echo "========================================"
        echo ""
        echo "Cluster Information:"
        kubectl cluster-info
        echo ""
        echo "Node Information:"
        kubectl get nodes -o wide
        echo ""
        echo "Namespace Summary:"
        kubectl get namespaces
        echo ""
        echo "Pod Summary by Namespace:"
        kubectl get pods --all-namespaces --no-headers | awk '{print $1}' | sort | uniq -c
        echo ""
        echo "Security Tools:"
        echo "- kube-bench: $(command -v kube-bench &> /dev/null && echo "Installed" || echo "Not installed")"
        echo "- trivy: $(command -v trivy &> /dev/null && echo "Installed" || echo "Not installed")"
        echo "- falco: $(kubectl get pods -n security-tools -l app.kubernetes.io/name=falco --no-headers 2>/dev/null | wc -l) pods running"
    } > "$report_file"

    print_status "PASS" "Validation report saved to: $report_file"
}

# Main execution function
main() {
    echo "CKS Cluster Validation Script"
    echo "============================"
    echo ""

    check_kubectl
    check_cluster
    run_kube_bench
    check_privileged_pods
    check_root_pods
    check_host_fs_mounts
    check_network_policies
    check_pss
    check_rbac
    check_api_server
    check_security_tools
    check_vulnerable_images
    generate_report

    echo ""
    print_status "INFO" "Validation completed successfully!"
    print_status "INFO" "Review the WARN and FAIL messages above for security improvements"
}

# Run the main function
main "$@"
#!/bin/bash

# CKS Practice Scenarios Setup Script
# This script sets up and manages CKS practice scenarios

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
check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        print_status "FAIL" "kubectl is not installed or not in PATH"
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        print_status "FAIL" "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    print_status "PASS" "Prerequisites check passed"
}

# Function to create namespaces
create_namespaces() {
    print_status "INFO" "Creating namespaces for CKS practice..."

    # cks-practice namespace
    kubectl create namespace cks-practice --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace cks-practice pod-security.kubernetes.io/enforce=baseline --overwrite
    kubectl label namespace cks-practice pod-security.kubernetes.io/audit=restricted --overwrite
    kubectl label namespace cks-practice pod-security.kubernetes.io/warn=restricted --overwrite

    # network-security namespace
    kubectl create namespace network-security --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace network-security pod-security.kubernetes.io/enforce=restricted --overwrite
    kubectl label namespace network-security pod-security.kubernetes.io/audit=restricted --overwrite
    kubectl label namespace network-security pod-security.kubernetes.io/warn=restricted --overwrite

    # security-tools namespace
    kubectl create namespace security-tools --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace security-tools pod-security.kubernetes.io/enforce=privileged --overwrite

    print_status "PASS" "Namespaces created successfully"
}

# Function to deploy vulnerable scenarios
deploy_scenarios() {
    print_status "INFO" "Deploying CKS practice scenarios..."

    if [[ -f "/Users/noroom113/selfproject/cks-lab/manifests/practice/cks-scenarios.yaml" ]]; then
        kubectl apply -f /Users/noroom113/selfproject/cks-lab/manifests/practice/cks-scenarios.yaml
        print_status "PASS" "CKS scenarios deployed"
    else
        print_status "FAIL" "CKS scenarios file not found"
        exit 1
    fi
}

# Function to deploy network policies
deploy_network_policies() {
    print_status "INFO" "Deploying network security policies..."

    if [[ -f "/Users/noroom113/selfproject/cks-lab/manifests/security/network-policies.yaml" ]]; then
        kubectl apply -f /Users/noroom113/selfproject/cks-lab/manifests/security/network-policies.yaml
        print_status "PASS" "Network policies deployed"
    else
        print_status "FAIL" "Network policies file not found"
        exit 1
    fi
}

# Function to deploy security tools
deploy_security_tools() {
    print_status "INFO" "Deploying security tools..."

    if [[ -f "/Users/noroom113/selfproject/cks-lab/manifests/security/falco-deployment.yaml" ]]; then
        kubectl apply -f /Users/noroom113/selfproject/cks-lab/manifests/security/falco-deployment.yaml
        print_status "PASS" "Falco security tool deployed"
    else
        print_status "WARN" "Falco deployment file not found, skipping..."
    fi
}

# Function to wait for pods to be ready
wait_for_pods() {
    print_status "INFO" "Waiting for pods to be ready..."

    # Wait for cks-practice pods
    kubectl wait --for=condition=ready pods -n cks-practice --all --timeout=300s || true

    # Wait for network-security pods
    kubectl wait --for=condition=ready pods -n network-security --all --timeout=300s || true

    # Wait for security-tools pods
    kubectl wait --for=condition=ready pods -n security-tools --all --timeout=300s || true

    print_status "PASS" "Pod readiness check completed"
}

# Function to show scenario summary
show_scenario_summary() {
    print_status "INFO" "CKS Practice Scenarios Summary:"
    echo ""

    echo "Vulnerable Pods in cks-practice namespace:"
    kubectl get pods -n cks-practice -l security-issue -o custom-columns=NAME:.metadata.name,ISSUE:.metadata.labels.security-issue,SCENARIO:.metadata.labels.scenario

    echo ""
    echo "Secure Pods for comparison:"
    kubectl get pods -n cks-practice -l security-status=secure -o custom-columns=NAME:.metadata.name,STATUS:.metadata.labels.security-status

    echo ""
    echo "Network Security Deployments:"
    kubectl get deployments -n network-security -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas

    echo ""
    echo "Security Tools Status:"
    kubectl get pods -n security-tools -o wide

    echo ""
    print_status "INFO" "Use the following commands to explore scenarios:"
    echo "  kubectl get pods -n cks-practice -l security-issue=privileged"
    echo "  kubectl describe pod <pod-name> -n cks-practice"
    echo "  kubectl exec -it <pod-name> -n cks-practice -- /bin/bash"
    echo ""
    echo "For practice instructions, check the ConfigMap:"
    echo "  kubectl get configmap practice-instructions -n cks-practice -o yaml"
}

# Function to clean up scenarios
cleanup_scenarios() {
    print_status "INFO" "Cleaning up CKS practice scenarios..."

    # Delete all pods in cks-practice namespace
    kubectl delete pods --all -n cks-practice --ignore-not-found=true

    # Delete all deployments in network-security namespace
    kubectl delete deployments --all -n network-security --ignore-not-found=true

    # Delete all services in network-security namespace
    kubectl delete services --all -n network-security --ignore-not-found=true

    # Delete network policies
    kubectl delete networkpolicies --all -n network-security --ignore-not-found=true
    kubectl delete networkpolicies --all -n cks-practice --ignore-not-found=true

    print_status "PASS" "Scenarios cleaned up"
}

# Function to reset and redeploy
reset_scenarios() {
    print_status "INFO" "Resetting CKS practice scenarios..."
    cleanup_scenarios
    sleep 5
    deploy_scenarios
    deploy_network_policies
    wait_for_pods
    show_scenario_summary
}

# Function to run security checks on scenarios
check_scenarios() {
    print_status "INFO" "Running security checks on scenarios..."

    echo ""
    echo "=== Privileged Pods ==="
    kubectl get pods -n cks-practice -o json | jq -r '.items[] | select(.spec.containers[].securityContext.privileged == true) | "Pod: \(.metadata.name) (Namespace: \(.metadata.namespace)) - PRIVILEGED: \(.spec.containers[].securityContext.privileged)"' || echo "No privileged pods found"

    echo ""
    echo "=== Pods Running as Root ==="
    kubectl get pods -n cks-practice -o json | jq -r '.items[] | select(.spec.containers[].securityContext.runAsUser == 0) | "Pod: \(.metadata.name) (Namespace: \(.metadata.namespace)) - RunAsUser: \(.spec.containers[].securityContext.runAsUser)"' || echo "No pods running as root found"

    echo ""
    echo "=== Host Filesystem Mounts ==="
    kubectl get pods -n cks-practice -o json | jq -r '.items[] | select(.spec.volumes[].hostPath != null) | "Pod: \(.metadata.name) (Namespace: \(.metadata.namespace)) - HostPath: \(.spec.volumes[].hostPath.path)"' || echo "No host filesystem mounts found"

    echo ""
    echo "=== Service Accounts ==="
    kubectl get pods -n cks-practice -o json | jq -r '.items[] | "Pod: \(.metadata.name) - ServiceAccount: \(.spec.serviceAccountName // "default")"'

    echo ""
    echo "=== Network Policies ==="
    kubectl get networkpolicy -n network-security -o custom-columns=NAME:.metadata.name,POD_SELECTOR:.spec.podSelector.matchLabels --no-headers || echo "No network policies found"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup     - Set up CKS practice environment (default)"
    echo "  deploy    - Deploy scenarios only"
    echo "  cleanup   - Clean up all scenarios"
    echo "  reset     - Reset and redeploy scenarios"
    echo "  check     - Run security checks on scenarios"
    echo "  status    - Show current scenario status"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0           # Set up complete environment"
    echo "  $0 deploy    # Deploy scenarios to existing cluster"
    echo "  $0 check     # Run security analysis"
}

# Main execution logic
main() {
    local command="${1:-setup}"

    case $command in
        "setup")
            check_prerequisites
            create_namespaces
            deploy_security_tools
            deploy_scenarios
            deploy_network_policies
            wait_for_pods
            show_scenario_summary
            ;;
        "deploy")
            check_prerequisites
            create_namespaces
            deploy_scenarios
            deploy_network_policies
            wait_for_pods
            show_scenario_summary
            ;;
        "cleanup")
            check_prerequisites
            cleanup_scenarios
            ;;
        "reset")
            check_prerequisites
            reset_scenarios
            ;;
        "check")
            check_prerequisites
            check_scenarios
            ;;
        "status")
            check_prerequisites
            show_scenario_summary
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            print_status "FAIL" "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run the main function
main "$@"
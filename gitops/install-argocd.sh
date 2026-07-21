#!/bin/bash

# Automated ArgoCD Installation Script for GKE
# This script automates the complete ArgoCD setup on Google Kubernetes Engine

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="${ARGOCD_VERSION:-5.51.0}"
HELM_REPO="https://argoproj.github.io/argo-helm"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Automated ArgoCD Installation for GKE            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to check command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print step
print_step() {
    echo -e "${YELLOW}[STEP]${NC} $1"
}

# Function to print success
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to print error
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Check prerequisites
print_step "Checking prerequisites..."

if ! command_exists kubectl; then
    print_error "kubectl not found. Please install kubectl first."
    exit 1
fi
print_success "kubectl found"

if ! command_exists helm; then
    print_error "helm not found. Please install helm first."
    exit 1
fi
print_success "helm found"

if ! command_exists gcloud; then
    print_error "gcloud not found. Please install Google Cloud SDK first."
    exit 1
fi
print_success "gcloud found"

# Check kubectl connectivity
print_step "Checking kubectl connectivity to cluster..."
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_error "Cannot connect to Kubernetes cluster. Please configure kubectl."
    exit 1
fi
print_success "Kubernetes cluster connectivity confirmed"

# Step 2: Create ArgoCD namespace
print_step "Creating ArgoCD namespace..."
kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
print_success "ArgoCD namespace created"

# Step 3: Add ArgoCD Helm repository
print_step "Adding ArgoCD Helm repository..."
helm repo add argo "$HELM_REPO" || helm repo update argo
print_success "ArgoCD Helm repository added"

# Step 4: Install ArgoCD using Helm
print_step "Installing ArgoCD using Helm (version: $ARGOCD_VERSION)..."
helm upgrade --install argocd argo/argo-cd \
    --namespace "$ARGOCD_NAMESPACE" \
    --version "$ARGOCD_VERSION" \
    --set server.service.type=LoadBalancer \
    --set redis.enabled=true \
    --set controller.replicas=1 \
    --wait --timeout=5m
print_success "ArgoCD installed successfully"

# Step 5: Wait for ArgoCD to be ready
print_step "Waiting for ArgoCD components to be ready..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-server -n "$ARGOCD_NAMESPACE" || {
    print_error "ArgoCD server did not become ready in time"
    exit 1
}
kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-application-controller -n "$ARGOCD_NAMESPACE" || {
    print_error "ArgoCD application controller did not become ready in time"
    exit 1
}
kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-repo-server -n "$ARGOCD_NAMESPACE" || {
    print_error "ArgoCD repo server did not become ready in time"
    exit 1
}
print_success "All ArgoCD components are ready"

# Step 6: Apply ArgoCD configuration
print_step "Applying ArgoCD configuration..."
if [ -f "$SCRIPT_DIR/argocd-namespace.yaml" ]; then
    kubectl apply -f "$SCRIPT_DIR/argocd-namespace.yaml"
    print_success "ArgoCD namespace configuration applied"
fi

if [ -f "$SCRIPT_DIR/argocd-config.yaml" ]; then
    kubectl apply -f "$SCRIPT_DIR/argocd-config.yaml"
    print_success "ArgoCD configuration applied"
fi

# Step 7: Get initial admin password
print_step "Retrieving initial admin password..."
ARGOCD_PASSWORD=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
print_success "Initial admin password retrieved"

# Step 8: Display access information
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           ArgoCD Installation Complete              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Access Information:${NC}"
echo -e "  Namespace: ${BLUE}$ARGOCD_NAMESPACE${NC}"
echo -e "  Username:  ${BLUE}admin${NC}"
echo -e "  Password:  ${BLUE}$ARGOCD_PASSWORD${NC}"
echo ""
echo -e "${YELLOW}Access ArgoCD UI:${NC}"
echo -e "  Option 1 (Port Forward):"
echo -e "    ${BLUE}kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443${NC}"
echo -e "    ${BLUE}Open browser: https://localhost:8080${NC}"
echo ""
echo -e "  Option 2 (LoadBalancer):"
echo -e "    ${BLUE}kubectl get svc argocd-server -n $ARGOCD_NAMESPACE${NC}"
echo -e "    ${BLUE}Open browser: https://<EXTERNAL-IP>${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Login to ArgoCD CLI:"
echo -e "     ${BLUE}argocd login <ARGOCD_SERVER> --username admin --password $ARGOCD_PASSWORD${NC}"
echo ""
echo -e "  2. Configure Git repository:"
echo -e "     ${BLUE}argocd repo add https://github.com/andre-svager/specialization-stage4.git --name gitops-repo${NC}"
echo ""
echo -e "  3. Deploy applications:"
echo -e "     ${BLUE}kubectl apply -f $SCRIPT_DIR/apps/${NC}"
echo ""
echo -e "${YELLOW}Change the initial password after first login!${NC}"
echo ""

# Optional: Deploy applications automatically if flag is set
if [ "$AUTO_DEPLOY_APPS" = "true" ]; then
    print_step "Auto-deploying applications..."
    if [ -d "$SCRIPT_DIR/apps" ]; then
        kubectl apply -f "$SCRIPT_DIR/apps/
        print_success "Applications deployed"
    else
        print_error "apps directory not found"
    fi
fi

echo -e "${GREEN}Installation completed successfully!${NC}"

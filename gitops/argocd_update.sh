#!/bin/bash

# ArgoCD Troubleshooting Script for GKE
# Diagnoses and fixes common ArgoCD pod scheduling issues

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     ArgoCD Troubleshooting for GKE                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Check ArgoCD pod status
echo -e "${YELLOW}[1] Checking ArgoCD pod status...${NC}"
kubectl get pods -n argocd
echo ""

# Check node resources
echo -e "${YELLOW}[2] Checking GKE node resources...${NC}"
if kubectl top nodes >/dev/null 2>&1; then
    kubectl top nodes
else
    echo -e "${RED}Metrics API not available. Checking node capacity instead...${NC}"
    kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory
fi
echo ""

# Check detailed pod descriptions
echo -e "${YELLOW}[3] Checking pod events and descriptions...${NC}"
echo -e "${BLUE}=== argocd-application-controller ===${NC}"
kubectl describe pod -l app.kubernetes.io/name=argocd-application-controller -n argocd | tail -30
echo ""
echo -e "${BLUE}=== argocd-applicationset-controller ===${NC}"
kubectl describe pod -l app.kubernetes.io/name=argocd-applicationset-controller -n argocd | tail -30
echo ""

# Check resource requests vs available
echo -e "${YELLOW}[4] Checking resource requests vs node capacity...${NC}"
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory
echo ""
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{.spec.containers[*].name}{": "}{.spec.containers[*].resources.requests.cpu}{"\n"}{end}' | grep -A1 "controller"
echo ""

# Check for taints
echo -e "${YELLOW}[5] Checking node taints...${NC}"
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
echo ""

# Check ArgoCD installation method
echo -e "${YELLOW}[6] Checking ArgoCD installation...${NC}"
kubectl get deployment -n argocd
kubectl get statefulset -n argocd
echo ""

# Provide solutions based on common issues
echo -e "${YELLOW}[7] Common Solutions:${NC}"
echo ""
echo -e "${GREEN}Solution 1: Scale down ArgoCD resources${NC}"
echo "kubectl patch deployment argocd-applicationset-controller -n argocd --type='json' -p='["
echo "  {\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/resources/requests/cpu\", \"value\": \"100m\"},"
echo "  {\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/resources/requests/memory\", \"value\": \"128Mi\"}"
echo "]'"
echo ""
echo -e "${GREEN}Solution 2: Check if node pool has sufficient resources${NC}"
echo "gcloud container node-pools describe default-pool --cluster=togglemaster-gke --region=us-central1"
echo ""
echo -e "${GREEN}Solution 3: Add more nodes to the cluster${NC}"
echo "gcloud container clusters resize togglemaster-gke --node-pool=default-pool --num-nodes=3 --region=us-central1"
echo ""
echo -e "${GREEN}Solution 3.5: Enable Metrics Server (required for kubectl top)${NC}"
echo "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
echo "Or for GKE: gcloud container clusters update togglemaster-gke --region=us-central1 --enable-metrics-server"
echo ""
echo -e "${GREEN}Solution 4: Remove resource limits temporarily${NC}"
echo "kubectl patch statefulset argocd-application-controller -n argocd --type='json' -p='["
echo "  {\"op\": \"remove\", \"path\": \"/spec/template/spec/containers/0/resources/limits\"}"
echo "]'"
echo ""
echo -e "${GREEN}Solution 5: Reinstall ArgoCD with reduced resources${NC}"
echo "helm upgrade argocd argo/argo-cd --namespace argocd --set controller.resources.requests.cpu=100m --set controller.resources.requests.memory=128Mi"
echo ""

echo -e "${YELLOW}[8] Quick Fix - Reduce ArgoCD resources${NC}"
read -p "Apply reduced resources fix? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Applying reduced resources..."
    kubectl patch deployment argocd-applicationset-controller -n argocd --type='json' -p='[
      {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value": "100m"},
      {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value": "128Mi"},
      {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value": "500m"},
      {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "512Mi"}
    ]' || true
    
    kubectl patch statefulset argocd-application-controller -n argocd --type='json' -p='[
      {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value": "100m"},
      {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value": "128Mi"},
      {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value": "500m"},
      {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "512Mi"}
    ]' || true
    
    echo "Waiting for pods to restart..."
    sleep 10
    kubectl get pods -n argocd
fi

echo ""
echo -e "${GREEN}Troubleshooting complete!${NC}"

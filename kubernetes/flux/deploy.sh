#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
FLUX_NAMESPACE="flux-system"
FLUX_CHART_VERSION="2.12.4"  # Update as needed
HELM_REPO_NAME="fluxcd-community"
HELM_REPO_URL="https://fluxcd-community.github.io/helm-charts"

echo -e "${GREEN}Deploying FluxCD to Kubernetes cluster${NC}"

# Check if kubectl is available and cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Cannot connect to Kubernetes cluster. Please check your kubeconfig.${NC}"
    exit 1
fi

echo -e "${YELLOW}Current cluster context:${NC}"
kubectl config current-context

# Add Flux Helm repository
echo -e "${YELLOW}Adding FluxCD Helm repository...${NC}"
helm repo add $HELM_REPO_NAME $HELM_REPO_URL
helm repo update

# Create namespace if it doesn't exist
echo -e "${YELLOW}Creating namespace: $FLUX_NAMESPACE${NC}"
kubectl create namespace $FLUX_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Install or upgrade FluxCD
echo -e "${YELLOW}Installing/Upgrading FluxCD...${NC}"
helm upgrade --install flux $HELM_REPO_NAME/flux2 \
    --namespace $FLUX_NAMESPACE \
    --version $FLUX_CHART_VERSION \
    --values values.yaml \
    --wait

# Verify installation
echo -e "${YELLOW}Verifying FluxCD installation...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=flux --namespace $FLUX_NAMESPACE --timeout=300s

echo -e "${GREEN}FluxCD deployed successfully!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Configure your Git repository for GitOps"
echo "2. Create GitRepository and Kustomization resources"
echo "3. Bootstrap your applications"

echo -e "${YELLOW}Useful commands:${NC}"
echo "  Check FluxCD status: flux get all -A"
echo "  View logs: kubectl logs -n $FLUX_NAMESPACE -l app.kubernetes.io/part-of=flux"
echo "  Reconcile: flux reconcile source git <source-name>"
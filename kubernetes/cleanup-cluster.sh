#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Force cleaning up Kubernetes cluster...${NC}"

# List of namespaces to clean up (keeping system ones)
NAMESPACES_TO_DELETE=(
    "cert-manager"
    "cloudflare" 
    "glance"
    "longhorn-system"
    "monitoring"
    "postgres"
    "traefik"
    "uptime-kuma"
    "flux-system"
)

# Force delete all application namespaces immediately
echo -e "${YELLOW}Force deleting namespaces...${NC}"
for ns in "${NAMESPACES_TO_DELETE[@]}"; do
    echo -e "${YELLOW}Force deleting namespace: $ns${NC}"
    kubectl delete namespace "$ns" --force --grace-period=0 --ignore-not-found=true &
done

# Wait a moment for the deletions to start
sleep 5

# Force remove any stuck finalizers
echo -e "${YELLOW}Removing stuck finalizers...${NC}"
for ns in "${NAMESPACES_TO_DELETE[@]}"; do
    kubectl patch namespace "$ns" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
done

# Force delete any remaining pods
echo -e "${YELLOW}Force deleting remaining pods...${NC}"
kubectl delete pods --all --all-namespaces --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true

# Force delete PVCs
echo -e "${YELLOW}Force deleting PVCs...${NC}"
kubectl delete pvc --all --all-namespaces --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true

# Force delete PVs
echo -e "${YELLOW}Force deleting PVs...${NC}"
kubectl delete pv --all --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true

# Clean up helm releases
echo -e "${YELLOW}Cleaning up helm releases...${NC}"
helm list --all-namespaces -q | xargs -r helm uninstall 2>/dev/null || true

# Wait a bit for everything to settle
sleep 10

echo -e "${GREEN}Force cleanup completed!${NC}"
echo -e "${YELLOW}Remaining pods:${NC}"
kubectl get pods --all-namespaces
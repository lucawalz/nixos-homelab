#!/bin/bash

set -e

echo "Updating kustomizations with SOPS decryption configuration..."

# Delete existing kustomizations to force recreation
kubectl delete kustomization homelab-apps homelab-infrastructure -n flux-system --ignore-not-found=true

# Wait a moment for cleanup
sleep 5

# Reapply the gitops configuration
kubectl apply -f gitops-repo.yaml

# Verify the decryption sections are present
echo "Checking homelab-apps decryption config:"
kubectl get kustomization homelab-apps -n flux-system -o yaml | grep -A 5 "decryption" || echo "No decryption config found"

echo "Checking homelab-infrastructure decryption config:"
kubectl get kustomization homelab-infrastructure -n flux-system -o yaml | grep -A 5 "decryption" || echo "No decryption config found"

echo "Force reconciling kustomizations..."
flux reconcile kustomization homelab-apps
flux reconcile kustomization homelab-infrastructure

echo "Done! Check status with: flux get kustomizations"
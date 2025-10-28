#!/bin/bash

# FluxCD Bootstrap Script for NixOS Homelab
# This script will bootstrap FluxCD on your cluster

set -e

echo "🚀 Bootstrapping FluxCD..."

# Check if flux CLI is installed
if ! command -v flux &> /dev/null; then
    echo "❌ Flux CLI not found. Please install it first:"
    echo "   curl -s https://fluxcd.io/install.sh | sudo bash"
    exit 1
fi

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ kubectl not configured or cluster not accessible"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Prompt for Git repository details
read -p "Enter your Git repository URL (e.g., ssh://git@github.com/username/repo): " GIT_URL
read -p "Enter the branch name (default: main): " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-main}

echo "📦 Bootstrapping Flux with:"
echo "   Repository: $GIT_URL"
echo "   Branch: $GIT_BRANCH"
echo "   Path: ./kubernetes"

# Bootstrap Flux
flux bootstrap git \
  --url="$GIT_URL" \
  --branch="$GIT_BRANCH" \
  --path=./kubernetes \
  --components-extra=image-reflector-controller,image-automation-controller

echo "✅ FluxCD bootstrap completed!"
echo ""
echo "📝 Next steps:"
echo "1. Encrypt your Cloudflare API token:"
echo "   sops -e -i kubernetes/infrastructure/cert-manager/cloudflare-secret.yaml"
echo ""
echo "2. Update email addresses in:"
echo "   - kubernetes/infrastructure/traefik/helmrelease.yaml"
echo "   - kubernetes/infrastructure/cert-manager/cluster-issuer.yaml"
echo ""
echo "3. Commit and push your changes:"
echo "   git add ."
echo "   git commit -m 'Add FluxCD bootstrap and initial services'"
echo "   git push"
echo ""
echo "4. Monitor the deployment:"
echo "   flux get kustomizations --watch"
echo "   kubectl get pods -A"
#!/bin/bash

# FluxCD Bootstrap Script for NixOS Homelab with Token Authentication
# This script will bootstrap FluxCD on your cluster using GitHub token auth

set -e

echo "🚀 Bootstrapping FluxCD with token authentication..."

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

# Check if sops is installed
if ! command -v sops &> /dev/null; then
    echo "❌ sops not found. Please install it first"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Prompt for Git repository details
read -p "Enter your GitHub repository URL (https://github.com/username/repo): " GIT_URL
read -p "Enter your GitHub username: " GITHUB_USERNAME
read -s -p "Enter your GitHub personal access token: " GITHUB_TOKEN
echo ""
read -p "Enter the branch name (default: main): " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-main}

echo "📦 Creating encrypted Git authentication secret..."

# Create the secret temporarily
kubectl create secret generic flux-system \
  --from-literal=username="$GITHUB_USERNAME" \
  --from-literal=password="$GITHUB_TOKEN" \
  --namespace=flux-system \
  --dry-run=client -o yaml > kubernetes/infrastructure/flux-system/git-auth-secret.yaml

# Encrypt the secret with sops
sops -e -i kubernetes/infrastructure/flux-system/git-auth-secret.yaml

echo "✅ Git authentication secret encrypted"

# Update the GitRepository URL in gotk-sync.yaml
sed -i.bak "s|url: https://github.com/your-username/your-repo|url: $GIT_URL|g" kubernetes/infrastructure/flux-system/gotk-sync.yaml
rm kubernetes/infrastructure/flux-system/gotk-sync.yaml.bak

echo "📦 Bootstrapping Flux with:"
echo "   Repository: $GIT_URL"
echo "   Branch: $GIT_BRANCH"
echo "   Path: ./kubernetes"
echo "   Auth: Token-based (encrypted with sops)"

# Bootstrap Flux using token authentication
export GITHUB_TOKEN="$GITHUB_TOKEN"
flux bootstrap github \
  --owner="$(echo $GIT_URL | cut -d'/' -f4)" \
  --repository="$(echo $GIT_URL | cut -d'/' -f5)" \
  --branch="$GIT_BRANCH" \
  --path=./kubernetes \
  --personal \
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
echo ""
echo "🔐 Your Git token is now encrypted with sops and stored in:"
echo "   kubernetes/infrastructure/flux-system/git-auth-secret.yaml"
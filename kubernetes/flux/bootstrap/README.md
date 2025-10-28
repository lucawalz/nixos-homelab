# FluxCD Bootstrap Configuration

This directory contains the GitOps bootstrap configuration for FluxCD.

## Setup Instructions

1. **Update the Git repository URL** in `gitops-repo.yaml`:
   ```yaml
   url: https://github.com/YOUR_USERNAME/YOUR_REPO_NAME
   ```

2. **For private repositories**, create a secret with Git credentials:
   ```bash
   kubectl create secret generic git-credentials \
     --namespace=flux-system \
     --from-literal=username=YOUR_USERNAME \
     --from-literal=password=YOUR_TOKEN
   ```

3. **Apply the bootstrap configuration**:
   ```bash
   kubectl apply -f gitops-repo.yaml
   ```

4. **Verify the setup**:
   ```bash
   flux get sources git
   flux get kustomizations
   ```

## Directory Structure Expected by FluxCD

Your repository should have this structure for the GitOps setup to work:

```
kubernetes/
├── apps/           # Application deployments
├── infrastructure/ # Core infrastructure
└── flux/          # FluxCD configuration (this directory)
```

## Troubleshooting

- Check FluxCD logs: `kubectl logs -n flux-system -l app.kubernetes.io/part-of=flux`
- Force reconciliation: `flux reconcile source git homelab-repo`
- Check resource status: `flux get all -A`
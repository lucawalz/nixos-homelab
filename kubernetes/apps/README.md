# Applications

This directory contains application deployments managed by FluxCD.

## Structure

Each application should have its own subdirectory with:
- `kustomization.yaml` - Kustomize configuration
- `namespace.yaml` - Namespace definition
- `helmrelease.yaml` - Helm release configuration (if using Helm)
- `values.yaml` - Application-specific values

## Example Applications

Future services you might want to deploy here:
- Gitea (Git server)
- Jellyfin (Media server)
- Homepage (Dashboard)
- Grafana (Monitoring)
- Paperless (Document management)
- And more...
# Kubernetes Services

This directory contains all Kubernetes-related deployments and configurations for the homelab.

## Structure

- `flux/` - FluxCD deployment and configuration
- `apps/` - Application deployments (future services)
- `infrastructure/` - Core infrastructure components
- `monitoring/` - Monitoring stack (Prometheus, Grafana, etc.)
- `storage/` - Storage-related configurations

## Getting Started

1. Deploy FluxCD first: `cd flux && ./deploy.sh`
2. Configure your Git repository for GitOps
3. Deploy additional services as needed
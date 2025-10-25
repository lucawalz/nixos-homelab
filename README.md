# NixOS Homelab

A complete homelab infrastructure setup using NixOS and Kubernetes (K3s), managed declaratively.

## Infrastructure Overview

- **OS:** NixOS (managed with Flakes)
- **Kubernetes:** K3s (2 nodes: master + worker-1)
- **Domain:** syslabs.dev
- **Storage:** Longhorn (distributed block storage)
- **Ingress:** Traefik
- **External Access:** Cloudflare Tunnel
- **Monitoring:** Prometheus + Grafana
- **Certificate Management:** cert-manager (dormant)

## Repository Structure

```
nixos-homelab/
├── nixos/                    # NixOS system configurations
│   ├── configuration.nix     # Main system configuration
│   ├── disko-config.nix      # Disk partitioning (Disko)
│   ├── flake.nix            # Nix flake for reproducibility
│   ├── flake.lock           # Locked dependencies
│   └── secrets/             # Secrets (not in git)
│
└── k3s-manifest/            # Kubernetes manifests
    ├── cert-manager/        # TLS certificate automation
    ├── cloudflare/          # Cloudflare Tunnel configuration
    ├── longhorn/            # Distributed storage
    ├── monitoring/          # Prometheus + Grafana stack
    └── traefik/             # Ingress middleware & config
```

## Getting Started

### NixOS Deployment

```bash
cd nixos
sudo nixos-rebuild switch --flake .
```

### K3s Deployment Order

1. **Longhorn** (Storage foundation)
   ```bash
   kubectl apply -f k3s-manifest/longhorn/
   ```

2. **Traefik Middleware** (Security headers)
   ```bash
   kubectl apply -f k3s-manifest/traefik/
   ```

3. **Cloudflare Tunnel** (External access)
   ```bash
   # Edit cloudflared-deployment.yaml and replace token placeholder
   kubectl create namespace cloudflare
   kubectl apply -f k3s-manifest/cloudflare/
   ```

4. **Monitoring Stack**
   ```bash
   kubectl apply -f k3s-manifest/monitoring/
   ```

5. **cert-manager** (Optional - for future use)
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
   kubectl apply -f k3s-manifest/cert-manager/
   ```

## Services

| Service | URL | Access |
|---------|-----|--------|
| Grafana | https://grafana.syslabs.dev | via Cloudflare Tunnel |

## Secrets Management

**Important:** Secrets are NOT stored in this repository and have to be added manually.

### Required Secrets:

1. **Cloudflare Tunnel Token**
   - Location: `k3s-manifest/cloudflare/cloudflared-deployment.yaml`
   - Replace: `REPLACE_WITH_YOUR_CLOUDFLARE_TUNNEL_TOKEN`
   - Get from: Cloudflare Zero Trust Dashboard → Networks → Tunnels

2. **NixOS Secrets**
   - Location: `nixos/secrets/` (gitignored)
   - Manage locally or use `agenix`/`sops-nix`

## Monitoring

Access Grafana at **https://grafana.syslabs.dev**

**Default credentials:** `admin` / `admin` (change immediately!)

### Quick Health Check

```bash
# Cluster status
kubectl get nodes
kubectl get pods -A

# Storage
kubectl get pvc -A

# Monitoring
kubectl get pods -n monitoring

# Ingress
kubectl get ingress -A
```

## Common Operations

### View logs
```bash
kubectl logs -n <namespace> <pod-name> -f
```

### Access Prometheus directly
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090
```

### Check Longhorn status
```bash
kubectl get pods -n longhorn-system
```

### Restart Cloudflare tunnel
```bash
kubectl rollout restart deployment/cloudflared -n cloudflare
```

## Maintenance

### Update NixOS
```bash
cd nixos
nix flake update
sudo nixos-rebuild switch --flake .
```

### Update K3s components
```bash
# Update cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.1/cert-manager.yaml

# Update monitoring images
kubectl set image deployment/grafana grafana=grafana/grafana:latest -n monitoring
kubectl set image deployment/prometheus prometheus=prom/prometheus:latest -n monitoring
```

### Backup
```bash
# Backup Kubernetes manifests
kubectl get all --all-namespaces -o yaml > cluster-backup-$(date +%Y%m%d).yaml

# Backup Longhorn volumes (use Longhorn UI)
# Access via kubectl port-forward if needed
```

## To-Do / Future Enhancements

- [ ] Set up automated Longhorn backups (S3/NFS)
- [ ] Add ArgoCD for GitOps workflow
- [ ] Implement network policies
- [ ] Add logging stack (Loki + Promtail)
- [ ] Set up Alertmanager for monitoring alerts
- [ ] Add more Grafana dashboards
- [ ] Implement secret management (sealed-secrets or external-secrets)
- [ ] Add CI/CD pipeline

## Troubleshooting

### Pod stuck in Pending
```bash
kubectl describe pod <pod-name> -n <namespace>
# Check events for PVC/resource issues
```

### Cloudflare tunnel not connecting
```bash
kubectl logs -n cloudflare -l app=cloudflared
# Look for "Connection registered" messages
```

### Storage issues
```bash
kubectl get pv,pvc -A
kubectl logs -n longhorn-system -l app=longhorn-manager
```

## Documentation

- [K3s Documentation](https://docs.k3s.io)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Longhorn Documentation](https://longhorn.io/docs)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Prometheus Documentation](https://prometheus.io/docs)

## Contributing

This is a personal homelab, but feel free to use it as inspiration for your own setup!

## License

This configuration is provided as-is for educational purposes.
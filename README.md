# NixOS Homelab Infrastructure

A fully declarative, reproducible homelab infrastructure using NixOS and Kubernetes (K3s) with GitOps via Flux CD and production-grade secret management.

[![NixOS](https://img.shields.io/badge/NixOS-unstable-blue.svg)](https://nixos.org)
[![K3s](https://img.shields.io/badge/K3s-Kubernetes-green.svg)](https://k3s.io)
[![Flux CD](https://img.shields.io/badge/GitOps-Flux_CD-purple.svg)](https://fluxcd.io)
[![SOPS](https://img.shields.io/badge/Secrets-SOPS-orange.svg)](https://github.com/getsops/sops)
[![agenix](https://img.shields.io/badge/Secrets-agenix-purple.svg)](https://github.com/ryantm/agenix)

**Domain:** syslabs.dev  
**Owner:** @lucawalz  
**Created:** October 2024

---

## Overview

This repository contains everything needed to deploy and manage a complete homelab infrastructure with GitOps automation:

- **Operating System:** NixOS (declarative Linux distribution)
- **Orchestration:** K3s (lightweight Kubernetes)
- **GitOps:** Flux CD (automated deployment from Git)
- **Storage:** Longhorn (distributed block storage)
- **Ingress:** Traefik (reverse proxy & load balancer)
- **Certificates:** cert-manager (automated TLS)
- **External Access:** Cloudflare Tunnel (secure external connectivity)
- **Monitoring:** Prometheus + Grafana (metrics & visualization)
- **Dashboard:** Homepage (unified homelab dashboard)
- **Secret Management:** SOPS + agenix (encrypted secrets in git)

---

## Repository Structure

```
nixos-homelab/
├── nixos/                    # NixOS system configurations
│   ├── configuration.nix     # Main system config (shared by all nodes)
│   ├── disko-config.nix      # Automated disk partitioning
│   ├── flake.nix            # Nix flake definition (infrastructure as code)
│   ├── flake.lock           # Locked dependencies for reproducibility
│   ├── secrets.nix          # agenix encryption key definitions
│   └── secrets/             # Encrypted NixOS secrets
│       ├── .gitignore       # Protects decrypted secrets
│       └── k3s-token.age    # Encrypted K3s cluster join token
│
├── k3s-manifest/            # Kubernetes application manifests
│   ├── flux/                # Flux CD GitOps configuration
│   │   ├── flux-gitrepository.yaml    # Git repository source
│   │   ├── flux-kustomization.yaml    # Deployment automation
│   │   └── secret.enc.yaml            # Encrypted SOPS key
│   ├── cert-manager/        # TLS certificate automation
│   ├── cloudflare/          # Cloudflare Tunnel for external access
│   ├── homepage/            # Homelab dashboard
│   ├── longhorn/            # Distributed storage system
│   ├── monitoring/          # Prometheus + Grafana stack
│   └── traefik/             # Ingress middleware configurations
│
├── .sops.yaml              # SOPS encryption configuration
├── .gitignore              # Git ignore rules (protects secrets)
├── README.md               # This file
└── SECRETS.md              # Secret management documentation
```

See individual README files in each directory for detailed documentation:
- [nixos/README.md](./nixos/README.md) - NixOS configuration guide
- [k3s-manifest/README.md](./k3s-manifest/README.md) - Kubernetes deployment guide

---

## Quick Start

### Prerequisites

**On your workstation (Mac/Linux):**
- Nix package manager installed
- SSH access to target machines
- Age keys generated for secret management

**Target machines:**
- x86_64 architecture
- UEFI boot support
- NVMe disk (`/dev/nvme0n1`)

### 1. Deploy NixOS with nixos-anywhere

Deploy the master node:
```bash
nixos-anywhere --flake github:lucawalz/nixos-homelab#master root@<master-ip>
```

Deploy worker nodes:
```bash
nixos-anywhere --flake github:lucawalz/nixos-homelab#worker-1 root@<worker-ip>
```

This will:
- Partition disks automatically (disko)
- Install NixOS with your configuration
- Set up K3s (server on master, agent on worker)
- Configure networking and services
- Create the `master` user with your SSH key

### 2. Access Your Cluster

Export the kubeconfig from master:
```bash
# Get kubeconfig
ssh master@<master-ip> "sudo cat /etc/rancher/k3s/k3s.yaml" | \
  sed "s/127.0.0.1/<master-ip>/" > ~/.kube/homelab.yaml

# Use it
export KUBECONFIG=~/.kube/homelab.yaml

# Verify cluster
kubectl get nodes
```

### 3. Bootstrap Flux CD (GitOps)

Install Flux CLI:
```bash
# macOS
brew install fluxcd/tap/flux

# Linux
curl -s https://fluxcd.io/install.sh | sudo bash
```

Bootstrap Flux CD to your cluster:
```bash
cd ~/nixos-homelab

# Install Flux controllers
flux install

# Deploy SOPS secret for decryption
sops -d k3s-manifest/flux/secret.enc.yaml | kubectl apply -f -

# Apply GitRepository source
kubectl apply -f k3s-manifest/flux/flux-gitrepository.yaml

# Apply Kustomization (starts automatic deployment)
kubectl apply -f k3s-manifest/flux/flux-kustomization.yaml

# Watch Flux deploy everything
flux get kustomizations --watch
```

**That's it!** Flux will now automatically deploy and manage all applications from this Git repository.

### 4. Verify Deployment

```bash
# Check Flux status
flux get sources git
flux get kustomizations

# Check all pods are running
kubectl get pods -A

# Access services
# - Grafana: https://grafana.syslabs.dev
# - Homepage: https://homepage.syslabs.dev
```

---

## GitOps Workflow with Flux CD

### How It Works

1. **You push changes** to this Git repository
2. **Flux detects changes** automatically (every 1 minute)
3. **Flux applies manifests** to the cluster
4. **Flux decrypts secrets** using SOPS automatically
5. **Applications update** without manual intervention

### Make Changes

```bash
# 1. Edit any manifest
vim k3s-manifest/monitoring/grafana-deployment.yaml

# 2. Commit and push
git add k3s-manifest/monitoring/grafana-deployment.yaml
git commit -m "Update Grafana to v10.0.0"
git push

# 3. Watch Flux apply changes (automatic!)
flux get kustomizations --watch

# Or force immediate reconciliation
flux reconcile kustomization flux-system --with-source
```

### Flux Commands Reference

```bash
# Check Flux installation
flux check

# View Git sources
flux get sources git

# View Kustomizations (deployments)
flux get kustomizations

# Force reconciliation (sync now)
flux reconcile kustomization flux-system --with-source

# Suspend/Resume automation
flux suspend kustomization flux-system
flux resume kustomization flux-system

# View events
flux events

# Logs from Flux controllers
flux logs --follow
```

---

## Secret Management

This repository uses **two** encryption systems:

| Tool | Purpose | Files | Decryption |
|------|---------|-------|------------|
| **SOPS** | Kubernetes secrets | `k3s-manifest/**/*.enc.yaml` | Flux + SOPS controller |
| **agenix** | NixOS system secrets | `nixos/secrets/*.age` | agenix at boot |

### SOPS with Flux CD

**Flux automatically decrypts SOPS-encrypted secrets** when applying manifests. No manual decryption needed!

```bash
# Edit encrypted secret
sops k3s-manifest/cloudflare/secret.enc.yaml

# Commit and push
git add k3s-manifest/cloudflare/secret.enc.yaml
git commit -m "Update Cloudflare token"
git push

# Flux automatically decrypts and applies (within 1 minute)
# Or force immediate sync:
flux reconcile kustomization flux-system --with-source
```

### Manual Secret Operations (if needed)

```bash
# View decrypted content
sops -d k3s-manifest/cloudflare/secret.enc.yaml

# Create new encrypted secret
cat > /tmp/secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: default
stringData:
  password: "super-secret"
EOF

sops -e /tmp/secret.yaml > k3s-manifest/myapp/secret.enc.yaml
rm /tmp/secret.yaml
```

### Working with agenix (NixOS Secrets)

```bash
cd nixos

# Edit secret
agenix -e secrets/k3s-token.age

# Deploy (automatic on nixos-rebuild)
sudo nixos-rebuild switch --flake .#master
```

**See [SECRETS.md](./SECRETS.md) for complete secret management guide.**

---

## Deployed Services

| Service | URL | Description |
|---------|-----|-------------|
| Homepage | https://homepage.syslabs.dev | Unified homelab dashboard |
| Grafana | https://grafana.syslabs.dev | Metrics visualization & dashboards |
| Prometheus | Internal (port 9090) | Metrics collection & storage |
| Longhorn UI | Internal (port 80) | Storage management interface |

**Default Grafana credentials:** `admin` / `admin` (change immediately!)

---

## Common Operations

### Update Application via GitOps

```bash
# 1. Edit manifest locally
vim k3s-manifest/monitoring/grafana-deployment.yaml

# 2. Commit and push
git add k3s-manifest/monitoring/grafana-deployment.yaml
git commit -m "Update Grafana image"
git push

# 3. Flux applies automatically
# Watch progress:
flux get kustomizations --watch
kubectl rollout status deployment/grafana -n monitoring
```

### Rebuild NixOS Configuration

On any node:
```bash
ssh master@<node-ip>
cd /path/to/nixos-homelab/nixos
git pull
sudo nixos-rebuild switch --flake .
```

### Scale K3s Worker Nodes

1. Add new configuration to `flake.nix`:
```nix
worker-2 = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { meta = { hostname = "worker-2"; }; };
  modules = [ /* ... */ ];
};
```

2. Deploy:
```bash
nixos-anywhere --flake .#worker-2 root@<new-worker-ip>
```

3. Verify in cluster:
```bash
kubectl get nodes
```

### View Logs

```bash
# Kubernetes pod logs
kubectl logs -n <namespace> <pod-name> -f

# All pods in namespace
kubectl logs -n monitoring -l app=prometheus --tail=50

# K3s service logs
ssh master@<node-ip> "sudo journalctl -u k3s -f"

# Flux logs
flux logs --follow
```

### Rollback Changes

```bash
# Git revert
git revert <commit-hash>
git push

# Flux will automatically apply the revert

# Or suspend Flux and manually fix
flux suspend kustomization flux-system
kubectl apply -f k3s-manifest/monitoring/grafana-deployment.yaml
flux resume kustomization flux-system
```

---

## Maintenance

### Update NixOS Packages

```bash
cd ~/nixos-homelab/nixos

# Update flake inputs
nix flake update

# Commit lockfile
git add flake.lock
git commit -m "Update NixOS packages"
git push

# Deploy to nodes
ssh master@<master-ip> "cd /path/to/repo && git pull && sudo nixos-rebuild switch --flake ."
```

### Update Kubernetes Applications

```bash
# Update image versions in manifests
vim k3s-manifest/monitoring/grafana-deployment.yaml

# Commit and push
git add k3s-manifest/monitoring/
git commit -m "Update monitoring stack"
git push

# Flux applies automatically!
```

### Rotate Secrets

#### Kubernetes Secret (SOPS)
```bash
# Edit encrypted secret
sops k3s-manifest/cloudflare/secret.enc.yaml

# Update the value, save

# Commit and push
git add k3s-manifest/cloudflare/secret.enc.yaml
git commit -m "Rotate Cloudflare token"
git push

# Flux applies automatically
# Restart affected pods if needed:
kubectl rollout restart deployment/cloudflared -n cloudflare
```

#### NixOS Secret (agenix)
```bash
cd ~/nixos-homelab/nixos

# Edit secret
agenix -e secrets/k3s-token.age
# Update value, save

# Commit and push
git add secrets/k3s-token.age
git commit -m "Rotate K3s token"
git push

# Rebuild affected nodes
ssh master@<worker-ip> "cd /path/to/repo && git pull && sudo nixos-rebuild switch --flake ."
```

---

## Troubleshooting

### Flux Not Syncing

```bash
# Check Flux status
flux check

# View reconciliation errors
flux get kustomizations
flux get sources git

# View Flux controller logs
flux logs --level=error

# Force reconciliation
flux reconcile kustomization flux-system --with-source
```

### SOPS Decryption Fails

```bash
# Check SOPS secret exists
kubectl get secret -n flux-system sops-age

# Check Flux can decrypt
flux logs | grep -i sops

# Verify .sops.yaml configuration
cat .sops.yaml

# Re-apply SOPS secret
sops -d k3s-manifest/flux/secret.enc.yaml | kubectl apply -f -
```

### Node Won't Boot
```bash
# Check if using correct disk device
# Edit nixos/disko-config.nix if needed
device = "/dev/nvme0n1";  # Or /dev/sda, /dev/vda, etc.
```

### K3s Agent Won't Join Cluster
```bash
# Check token is correct
ssh master@<worker-ip> "sudo journalctl -u k3s -n 50"

# Verify network connectivity to master
ssh master@<worker-ip> "ping -c 3 master"
ssh master@<worker-ip> "nc -zv master 6443"
```

### Pod Stuck in Pending
```bash
# Check events
kubectl describe pod <pod-name> -n <namespace>

# Common issues:
# - PVC not bound: Check Longhorn is running
# - Resource limits: Check node resources
# - Image pull errors: Check image name/tag
```

### Application Not Updating
```bash
# Verify Git has changes
git log

# Check Flux sees the changes
flux get sources git

# Force reconciliation
flux reconcile kustomization flux-system --with-source

# Check for errors
flux logs | grep -i error
```

---

## Architecture Details

### GitOps Flow

```
Developer
  ↓ git push
GitHub Repository (nixos-homelab)
  ↓ Flux monitors (every 1min)
Flux Controllers (in cluster)
  ↓ detects changes
SOPS Decryption (automatic)
  ↓
kubectl apply
  ↓
Kubernetes Resources Updated
```

### Network Flow

```
Internet
  ↓
Cloudflare Tunnel (cloudflared pods)
  ↓
Traefik Ingress Controller
  ↓
Kubernetes Services
  ↓
Application Pods
```

### Storage Architecture

```
Application Pods
  ↓
Persistent Volume Claims (PVC)
  ↓
Longhorn Volumes (replicated)
  ↓
Node Local Storage (/var/lib/longhorn)
```

### Secret Flow

**SOPS (K8s) with Flux:**
```
Encrypted in git (.enc.yaml)
  ↓
Flux detects change
  ↓
Flux + SOPS controller decrypts
  ↓
kubectl apply creates Secret (automatic!)
  ↓
Pods mount Secret as env var or file
```

**agenix (NixOS):**
```
Encrypted in git (.age)
  ↓
agenix decrypts at boot with SSH key
  ↓
Secret placed in /run/agenix/
  ↓
NixOS services reference path
```

---

## Additional Resources

### Official Documentation
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Flux CD Documentation](https://fluxcd.io/docs/)
- [K3s Documentation](https://docs.k3s.io)
- [Longhorn Docs](https://longhorn.io/docs)
- [SOPS Guide](https://github.com/getsops/sops)
- [agenix Guide](https://github.com/ryantm/agenix)

### Useful Commands Reference
- [Flux CLI Reference](https://fluxcd.io/flux/cmd/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [nix Command Reference](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix.html)

### Community
- [Flux CD Slack](https://cloud-native.slack.com/)
- [NixOS Discourse](https://discourse.nixos.org/)
- [K3s GitHub Discussions](https://github.com/k3s-io/k3s/discussions)

---

## Roadmap

- [x] GitOps with Flux CD
- [x] Automated secret decryption with SOPS
- [x] TLS certificates with cert-manager
- [x] Homelab dashboard with Homepage
- [ ] Automated Longhorn backups to S3/NFS
- [ ] Network policies for pod-to-pod security
- [ ] Loki + Promtail for log aggregation
- [ ] Alertmanager for monitoring alerts
- [ ] Multi-cluster federation
- [ ] Velero for disaster recovery

---

## Contributing

This is a personal homelab, but feel free to:
- Open issues for questions
- Submit PRs for improvements
- Use this as a template for your own homelab
- Share your customizations

---

## License

MIT License - use freely for your own projects!

---

## Acknowledgments

Built with amazing open-source tools:
- [NixOS](https://nixos.org) - Declarative Linux distribution
- [Flux CD](https://fluxcd.io) - GitOps for Kubernetes
- [K3s](https://k3s.io) - Lightweight Kubernetes
- [Longhorn](https://longhorn.io) - Cloud-native storage
- [SOPS](https://github.com/getsops/sops) - Secret management
- [agenix](https://github.com/ryantm/agenix) - Age-encrypted secrets for Nix
- [Cloudflare](https://www.cloudflare.com/) - Tunnel and DNS

---

**If you find this useful, consider starring the repo!**

**Questions? Open an issue or reach out to @lucawalz**
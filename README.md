# NixOS Homelab Infrastructure

A fully declarative, reproducible homelab infrastructure using NixOS and Kubernetes (K3s) with production-grade secret management.

[![NixOS](https://img.shields.io/badge/NixOS-unstable-blue.svg)](https://nixos.org)
[![K3s](https://img.shields.io/badge/K3s-Kubernetes-green.svg)](https://k3s.io)
[![SOPS](https://img.shields.io/badge/Secrets-SOPS-orange.svg)](https://github.com/getsops/sops)
[![agenix](https://img.shields.io/badge/Secrets-agenix-purple.svg)](https://github.com/ryantm/agenix)

**Domain:** syslabs.dev  
**Owner:** @lucawalz  
**Created:** October 2024

---

## Overview

This repository contains everything needed to deploy and manage a complete homelab infrastructure:

- **Operating System:** NixOS (declarative Linux distribution)
- **Orchestration:** K3s (lightweight Kubernetes)
- **Storage:** Longhorn (distributed block storage)
- **Ingress:** Traefik (reverse proxy & load balancer)
- **External Access:** Cloudflare Tunnel (secure external connectivity)
- **Monitoring:** Prometheus + Grafana (metrics & visualization)
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
│   ├── cloudflare/          # Cloudflare Tunnel for external access
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

### 3. Deploy Kubernetes Applications

Deploy in order:

```bash
# 1. Storage (required first)
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.7.2/deploy/longhorn.yaml

# 2. Cloudflare Tunnel (external access)
cd ~/nixos-homelab
sops -d k3s-manifest/cloudflare/secret.enc.yaml | kubectl apply -f -
kubectl apply -f k3s-manifest/cloudflare/

# 3. Monitoring stack
kubectl apply -f k3s-manifest/monitoring/

# 4. Verify everything
kubectl get pods -A
```

---

## Secret Management

This repository uses **two** encryption systems:

| Tool | Purpose | Files |
|------|---------|-------|
| **SOPS** | Kubernetes secrets | `k3s-manifest/**/*.enc.yaml` |
| **agenix** | NixOS system secrets | `nixos/secrets/*.age` |

### Working with SOPS (K8s Secrets)

```bash
# View encrypted secret
sops -d k3s-manifest/cloudflare/secret.enc.yaml

# Edit encrypted secret
sops k3s-manifest/cloudflare/secret.enc.yaml

# Deploy to cluster
sops -d k3s-manifest/cloudflare/secret.enc.yaml | kubectl apply -f -
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
| Grafana | https://grafana.syslabs.dev | Metrics visualization & dashboards |
| Prometheus | Internal (port 9090) | Metrics collection & storage |
| Longhorn UI | Internal (port 80) | Storage management interface |

**Default Grafana credentials:** `admin` / `admin` (change immediately!)

---

## Common Operations

### Rebuild NixOS Configuration

On any node:
```bash
ssh master@<node-ip>
cd /path/to/nixos-homelab/nixos
sudo nixos-rebuild switch --flake .
```

### Update Node Configuration

```bash
# Make changes locally
cd ~/nixos-homelab/nixos
vim configuration.nix

# Commit and push
git add .
git commit -m "Update config"
git push

# Pull and rebuild on node
ssh master@<node-ip> "cd /path/to/repo && git pull && sudo nixos-rebuild switch --flake ."
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

### View Logs

```bash
# K3s service logs
ssh master@<node-ip> "sudo journalctl -u k3s -f"

# Kubernetes pod logs
kubectl logs -n <namespace> <pod-name> -f

# All pods in namespace
kubectl logs -n monitoring -l app=prometheus --tail=50
```

### Backup & Restore

#### NixOS Configuration
```bash
# Everything is in git - just clone and deploy!
git clone https://github.com/lucawalz/nixos-homelab.git
```

#### Kubernetes State
```bash
# Backup all resources
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml

# Longhorn handles persistent volume backups
# Configure in: k3s-manifest/longhorn/backup-target.yaml
```

---

## Maintenance

### Update NixOS Packages

```bash
cd ~/nixos-homelab/nixos

# Update flake inputs
nix flake update

# Test build locally
nix build .#nixosConfigurations.master.config.system.build.toplevel

# Deploy to nodes
ssh master@<master-ip> "cd /path/to/repo && git pull && sudo nixos-rebuild switch --flake ."
```

### Update Kubernetes Applications

```bash
# Update image versions in manifests
vim k3s-manifest/monitoring/grafana-deployment.yaml

# Apply changes
kubectl apply -f k3s-manifest/monitoring/

# Or force restart
kubectl rollout restart deployment/grafana -n monitoring
```

### Rotate Secrets

#### Cloudflare Token
```bash
cd ~/nixos-homelab

# Edit and update token
sops k3s-manifest/cloudflare/secret.enc.yaml

# Commit
git add k3s-manifest/cloudflare/secret.enc.yaml
git commit -m "Rotate Cloudflare token"
git push

# Deploy
sops -d k3s-manifest/cloudflare/secret.enc.yaml | kubectl apply -f -
kubectl rollout restart deployment/cloudflared -n cloudflare
```

#### K3s Token
```bash
# Get new token from master
ssh master@<master-ip> "sudo cat /var/lib/rancher/k3s/server/node-token"

# Update encrypted secret
cd ~/nixos-homelab/nixos
agenix -e secrets/k3s-token.age
# Paste new token, save

# Commit and push
git add secrets/k3s-token.age
git commit -m "Rotate K3s token"
git push

# Rebuild worker nodes
ssh master@<worker-ip> "cd /path/to/repo && git pull && sudo nixos-rebuild switch --flake ."
```

---

## Troubleshooting

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

# Re-encrypt token if needed (see Rotate Secrets above)
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

### Grafana Not Accessible
```bash
# Check Cloudflare tunnel is running
kubectl get pods -n cloudflare
kubectl logs -n cloudflare -l app=cloudflared

# Check Grafana is running
kubectl get pods -n monitoring
kubectl logs -n monitoring -l app=grafana

# Check ingress
kubectl get ingress -n monitoring
```

### SOPS/agenix Decryption Fails
```bash
# Verify your age key exists
cat ~/.config/sops/age/keys.txt

# For SOPS
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops -d k3s-manifest/cloudflare/secret.enc.yaml

# For agenix - check SSH keys on nodes
ssh master@<node-ip> "cat /etc/ssh/ssh_host_ed25519_key.pub"
# Must match key in nixos/secrets.nix
```

---

## Architecture Details

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

**SOPS (K8s):**
```
Encrypted in git (.enc.yaml)
  ↓
SOPS decrypts with age key
  ↓
kubectl apply creates Secret
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
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [K3s Documentation](https://docs.k3s.io)
- [Longhorn Docs](https://longhorn.io/docs)
- [SOPS Guide](https://github.com/getsops/sops)
- [agenix Guide](https://github.com/ryantm/agenix)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

### Useful Commands Reference
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [nix Command Reference](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix.html)

### Community
- [NixOS Discourse](https://discourse.nixos.org/)
- [K3s GitHub Discussions](https://github.com/k3s-io/k3s/discussions)
- [r/NixOS](https://www.reddit.com/r/NixOS/)

---

## Roadmap

- [ ] Automated Longhorn backups to S3/NFS
- [ ] ArgoCD for GitOps workflow
- [ ] Network policies for pod-to-pod security
- [ ] Loki + Promtail for log aggregation
- [ ] Alertmanager for monitoring alerts
- [ ] Pre-configured Grafana dashboards
- [ ] CI/CD pipeline for validation
- [ ] Multi-cluster federation
- [ ] Automated certificate management with cert-manager
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
- [K3s](https://k3s.io) - Lightweight Kubernetes
- [Longhorn](https://longhorn.io) - Cloud-native storage
- [SOPS](https://github.com/getsops/sops) - Secret management
- [agenix](https://github.com/ryantm/agenix) - Age-encrypted secrets for Nix
- [Cloudflare](https://www.cloudflare.com/) - Tunnel and DNS

---

**If you find this useful, consider starring the repo!**

**Questions? Open an issue or reach out to @lucawalz**
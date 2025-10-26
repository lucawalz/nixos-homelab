# Kubernetes Manifests

This directory contains Kubernetes application manifests for the homelab cluster, automatically deployed via **Flux CD GitOps**.

---

## Overview

All applications in this directory are **automatically deployed and managed by Flux CD**. Simply commit changes to Git and Flux will apply them to the cluster within 1 minute.

### GitOps Workflow

1. **Edit manifest** in this directory
2. **Commit and push** to GitHub
3. **Flux detects change** automatically (polls every 1 minute)
4. **Flux applies manifest** to cluster
5. **Application updates** automatically

No manual `kubectl apply` needed! 🎉

---

## Directory Structure

```
k3s-manifest/
├── flux/                # Flux CD GitOps configuration
│   ├── flux-gitrepository.yaml    # Git repository source
│   ├── flux-kustomization.yaml    # Deployment automation
│   └── secret.enc.yaml            # Encrypted SOPS decryption key
│
├── cert-manager/        # TLS certificate automation
├── cloudflare/          # Cloudflare Tunnel for external access
├── homepage/            # Homelab dashboard
├── longhorn/            # Distributed block storage
├── monitoring/          # Prometheus + Grafana observability stack
└── traefik/             # Ingress middleware configurations
```

---

## Initial Setup (One-Time)

### 1. Install Flux CD

```bash
# Install Flux CLI
# macOS
brew install fluxcd/tap/flux

# Linux
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify
flux --version
```

### 2. Bootstrap Flux to Cluster

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

### 3. Verify Deployment

```bash
# Check Flux status
flux check

# View Git sources
flux get sources git

# View Kustomizations
flux get kustomizations

# Check all pods
kubectl get pods -A
```

**That's it!** Flux is now managing your cluster from Git.

---

## Deployment Order (Handled by Flux)

Flux automatically handles dependencies, but here's the logical order:

1. **Flux System** - GitOps controllers
2. **cert-manager** - TLS certificate management
3. **Longhorn** - Persistent storage (required by other apps)
4. **Traefik Middleware** - Security headers for ingress
5. **Cloudflare Tunnel** - External access
6. **Monitoring Stack** - Prometheus + Grafana
7. **Homepage** - Dashboard

---

## Application Details

### Flux CD (flux/)

**Purpose:** GitOps automation - deploys and manages everything from Git

**Components:**
- `flux-gitrepository.yaml` - Defines Git repo as source
- `flux-kustomization.yaml` - Defines what to deploy and how
- `secret.enc.yaml` - SOPS age key for secret decryption

**How it works:**
1. Flux monitors this Git repository every 1 minute
2. When changes are detected, Flux pulls the latest manifests
3. Flux decrypts SOPS-encrypted secrets automatically
4. Flux applies manifests to the cluster
5. Flux reports success/failure status

**Key Settings:**
```yaml
spec:
  interval: 1m              # Check for changes every minute
  path: ./k3s-manifest      # Deploy from this directory
  prune: true               # Delete resources removed from Git
  decryption:
    provider: sops          # Decrypt .enc.yaml files
    secretRef:
      name: sops-age        # Use this key for decryption
```

### cert-manager (cert-manager/)

**Purpose:** Automated TLS certificate management

**Features:**
- Automatic certificate issuance and renewal
- Let's Encrypt integration
- Cloudflare DNS validation

### Cloudflare Tunnel (cloudflare/)

**Purpose:** Secure external access without port forwarding

**Files:**
- `secret.enc.yaml` - Encrypted tunnel credentials (SOPS)
- `cloudflared-deployment.yaml` - Tunnel daemon

**Managed by Flux:** Yes - updates automatically on git push

### Homepage (homepage/)

**Purpose:** Unified homelab dashboard

**Access:** https://homepage.syslabs.dev

**Features:**
- Service status monitoring
- Quick links to all services
- Resource usage widgets

### Longhorn (longhorn/)

**Purpose:** Distributed persistent storage for Kubernetes

**Features:**
- Replicates volumes across nodes
- Snapshots and backups
- Web UI for management

**Storage Classes:**
- `longhorn` - Default, 3 replicas
- `longhorn-single` - Single replica (for testing)

### Monitoring Stack (monitoring/)

**Purpose:** Observability and metrics visualization

**Components:**
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards (https://grafana.syslabs.dev)
- **node-exporter** - Node-level metrics
- **kube-state-metrics** - Kubernetes object metrics

### Traefik Middleware (traefik/)

**Purpose:** Security headers for ingress traffic

**Features:**
- HSTS headers
- Content Security Policy
- XSS Protection
- Frame deny

---

## Working with GitOps

### Update Application

```bash
# 1. Edit manifest
vim k3s-manifest/monitoring/grafana-deployment.yaml

# 2. Commit and push
git add k3s-manifest/monitoring/grafana-deployment.yaml
git commit -m "Update Grafana to v10.0.0"
git push

# 3. Watch Flux apply changes (automatic!)
flux get kustomizations --watch

# Or force immediate sync
flux reconcile kustomization flux-system --with-source

# 4. Verify rollout
kubectl rollout status deployment/grafana -n monitoring
```

### Add New Application

```bash
# 1. Create directory and manifests
mkdir -p k3s-manifest/myapp

cat > k3s-manifest/myapp/namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
EOF

cat > k3s-manifest/myapp/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        ports:
        - containerPort: 8080
EOF

# 2. Commit and push
git add k3s-manifest/myapp/
git commit -m "Add myapp"
git push

# 3. Flux deploys automatically!
flux get kustomizations --watch
kubectl get pods -n myapp
```

### Remove Application

```bash
# 1. Delete directory
git rm -r k3s-manifest/myapp

# 2. Commit and push
git commit -m "Remove myapp"
git push

# 3. Flux removes resources automatically (because prune: true)
kubectl get ns myapp  # Should be gone after ~1 minute
```

### Rollback Changes

```bash
# Git revert
git revert <commit-hash>
git push

# Flux applies the revert automatically
```

---

## Secret Management with Flux

### How SOPS Works with Flux

Flux **automatically decrypts** SOPS-encrypted secrets when applying manifests. You never need to manually decrypt!

```bash
# Edit encrypted secret
sops k3s-manifest/cloudflare/secret.enc.yaml

# Commit and push
git add k3s-manifest/cloudflare/secret.enc.yaml
git commit -m "Update Cloudflare token"
git push

# Flux automatically:
# 1. Detects the change
# 2. Pulls the encrypted file
# 3. Decrypts it using the SOPS age key
# 4. Applies the decrypted Secret to the cluster
```

### Create New Encrypted Secret

```bash
# 1. Create plain YAML
cat > /tmp/my-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: default
type: Opaque
stringData:
  password: "super-secret"
  api-key: "abc123"
EOF

# 2. Encrypt with SOPS
sops -e /tmp/my-secret.yaml > k3s-manifest/myapp/secret.enc.yaml

# 3. Clean up plaintext
rm /tmp/my-secret.yaml

# 4. Commit encrypted file (safe!)
git add k3s-manifest/myapp/secret.enc.yaml
git commit -m "Add secret for myapp"
git push

# 5. Flux automatically decrypts and applies!
```

### View Encrypted Secret (Local)

```bash
# Decrypt to view (doesn't modify file)
sops -d k3s-manifest/cloudflare/secret.enc.yaml

# Edit and re-encrypt
sops k3s-manifest/cloudflare/secret.enc.yaml
```

### Verify Secret in Cluster

```bash
# Check secret exists
kubectl get secret cloudflare-tunnel-token -n cloudflare

# View secret content (base64 encoded)
kubectl get secret cloudflare-tunnel-token -n cloudflare -o yaml

# Decode secret value
kubectl get secret cloudflare-tunnel-token -n cloudflare -o jsonpath='{.data.token}' | base64 -d
```

---

## Flux Commands Reference

```bash
# === Status & Health ===
flux check                                    # Verify Flux installation
flux get sources git                          # View Git repositories
flux get kustomizations                       # View Kustomizations (deployments)
flux events                                   # View recent events

# === Force Sync ===
flux reconcile kustomization flux-system --with-source    # Sync now
flux reconcile source git flux-system                     # Update Git source

# === Suspend/Resume ===
flux suspend kustomization flux-system        # Pause automation
flux resume kustomization flux-system         # Resume automation

# === Logs ===
flux logs --follow                            # All Flux controller logs
flux logs --level=error                       # Only errors
flux logs --kind=Kustomization --name=flux-system  # Specific resource

# === Debugging ===
kubectl get gitrepositories -A                # Check Git sources
kubectl get kustomizations -A                 # Check Kustomizations
kubectl describe kustomization flux-system -n flux-system  # Details
```

---

## Accessing Services

### Via Cloudflare Tunnel (External)

- **Homepage:** https://homepage.syslabs.dev
- **Grafana:** https://grafana.syslabs.dev

### Via Port Forward (Internal)

```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# http://localhost:9090

# Grafana (if tunnel down)
kubectl port-forward -n monitoring svc/grafana 3000:3000
# http://localhost:3000

# Longhorn UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# http://localhost:8080

# Homepage (local)
kubectl port-forward -n homepage svc/homepage 8081:3000
# http://localhost:8081
```

---

## Troubleshooting

### Flux Not Syncing

```bash
# Check Flux health
flux check

# View status
flux get sources git
flux get kustomizations

# View errors
flux logs --level=error

# Force sync
flux reconcile kustomization flux-system --with-source
```

### SOPS Decryption Fails

```bash
# Check SOPS secret exists
kubectl get secret -n flux-system sops-age

# View Flux logs for SOPS errors
flux logs | grep -i sops

# Verify .sops.yaml configuration
cat .sops.yaml

# Re-apply SOPS secret
sops -d k3s-manifest/flux/secret.enc.yaml | kubectl apply -f -

# Restart Flux controllers
flux suspend kustomization flux-system
flux resume kustomization flux-system
```

### Application Not Updating

```bash
# Verify Git has latest changes
git log

# Check Flux sees the changes
flux get sources git

# Check last sync time
flux get kustomizations

# Force reconciliation
flux reconcile kustomization flux-system --with-source

# View reconciliation events
flux events --for Kustomization/flux-system
```

### Pod Stuck in Pending

```bash
# Check events
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - PVC not bound: Check Longhorn is running
# - Insufficient resources: Check node resources
# - Node selector mismatch: Check node labels
```

### Service Not Accessible

```bash
# Check service exists
kubectl get svc -n <namespace>

# Check endpoints (pod IPs)
kubectl get endpoints -n <namespace>

# Check pods are running
kubectl get pods -n <namespace>

# Check ingress
kubectl get ingress -n <namespace>

# Check Cloudflare tunnel
kubectl logs -n cloudflare -l app=cloudflared --tail=50
```

### View Application Logs

```bash
# Specific pod
kubectl logs -n monitoring grafana-xxx-yyy -f

# All pods with label
kubectl logs -n monitoring -l app=grafana --tail=50 -f

# Previous container (if crashed)
kubectl logs -n monitoring grafana-xxx-yyy -p
```

---

## Manual Operations (When Needed)

### Temporarily Disable GitOps

```bash
# Suspend Flux
flux suspend kustomization flux-system

# Make manual changes
kubectl apply -f /tmp/emergency-fix.yaml

# Resume Flux when ready
flux resume kustomization flux-system
```

### Manual Secret Deployment

```bash
# If Flux SOPS decryption fails, deploy manually
sops -d k3s-manifest/cloudflare/secret.enc.yaml | kubectl apply -f -
```

### Force Pod Restart

```bash
# Graceful rollout restart
kubectl rollout restart deployment/grafana -n monitoring

# Force delete pods
kubectl delete pod -n monitoring -l app=grafana
```

---

## Best Practices

### 1. Always Use Git

```bash
# ❌ DON'T: kubectl apply directly
kubectl apply -f /tmp/manual-change.yaml

# ✅ DO: Commit to Git and let Flux apply
git add k3s-manifest/myapp/
git commit -m "Update myapp"
git push
```

### 2. Use Meaningful Commit Messages

```bash
# ❌ Bad
git commit -m "update"

# ✅ Good
git commit -m "monitoring: Upgrade Grafana to v10.0.0"
```

### 3. Test Changes Locally First

```bash
# Validate YAML syntax
kubectl apply --dry-run=client -f k3s-manifest/myapp/

# Check SOPS encryption
sops -d k3s-manifest/myapp/secret.enc.yaml
```

### 4. Monitor Flux Events

```bash
# Watch for issues
flux events --watch

# Check logs regularly
flux logs --since=1h
```

### 5. Use Resource Limits

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### 6. Use Health Checks

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
```

---

## Resources

- [Flux CD Documentation](https://fluxcd.io/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [SOPS Documentation](https://github.com/getsops/sops)
- [K3s Documentation](https://docs.k3s.io/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

**Need more details? Check the README in each application directory!**

**Questions about GitOps workflow? See the main [README](../README.md)**
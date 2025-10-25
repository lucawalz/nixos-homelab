# Kubernetes Manifests

This directory contains Kubernetes application manifests for the homelab cluster.

## Directory Structure

```
k3s-manifest/
├── cloudflare/          # Cloudflare Tunnel for external access
├── longhorn/            # Distributed block storage
├── monitoring/          # Prometheus + Grafana observability stack
└── traefik/             # Ingress middleware configurations
```

---

## Deployment Order

Deploy applications in this order to satisfy dependencies:

### 1. Storage Foundation (Longhorn)

```bash
# Install Longhorn
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.7.2/deploy/longhorn.yaml

# Wait for Longhorn to be ready
kubectl wait --for=condition=ready pod -n longhorn-system -l app=longhorn-manager --timeout=300s

# Apply backup configuration (optional)
kubectl apply -f k3s-manifest/longhorn/backup-target.yaml
```

**Why first?** Other applications need persistent storage (PVCs).

### 2. Ingress Middleware (Traefik)

```bash
# Apply security headers middleware
kubectl apply -f k3s-manifest/traefik/
```

**Note:** Traefik itself is built into K3s, we're just adding middleware.

### 3. External Access (Cloudflare Tunnel)

```bash
# Decrypt and apply secret
sops -d k3s-manifest/cloudflare/secret.enc.yaml | kubectl apply -f -

# Deploy cloudflared
kubectl apply -f k3s-manifest/cloudflare/cloudflared-deployment.yaml

# Verify tunnel is connected
kubectl logs -n cloudflare -l app=cloudflared --tail=20
```

### 4. Monitoring Stack (Prometheus + Grafana)

```bash
# Deploy entire monitoring stack
kubectl apply -f k3s-manifest/monitoring/

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -n monitoring -l app=grafana --timeout=300s
kubectl wait --for=condition=ready pod -n monitoring -l app=prometheus --timeout=300s

# Access Grafana
# https://grafana.syslabs.dev (via Cloudflare Tunnel)
# Default credentials: admin / admin
```

---

## Application Details

### Cloudflare Tunnel

**Purpose:** Secure external access without port forwarding

**Components:**
- `secret.enc.yaml` - Encrypted Cloudflare tunnel token (SOPS)
- `cloudflared-deployment.yaml` - Deployment with 2 replicas

**Configuration:**
```yaml
spec:
  replicas: 2  # Redundancy
  containers:
    - image: cloudflare/cloudflared:latest
      env:
        - name: TUNNEL_TOKEN
          valueFrom:
            secretKeyRef:
              name: cloudflare-tunnel-token
              key: token
```

**See:** [cloudflare/README.md](./cloudflare/README.md)

### Longhorn

**Purpose:** Distributed persistent storage for Kubernetes

**Features:**
- Replicates volumes across nodes
- Snapshots and backups
- Web UI for management

**Storage Classes:**
- `longhorn` - Default, 3 replicas
- `longhorn-single` - Single replica (for testing)

**See:** [longhorn/README.md](./longhorn/README.md)

### Monitoring Stack

**Purpose:** Observability and metrics visualization

**Components:**
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **node-exporter** - Node-level metrics (CPU, RAM, disk)
- **kube-state-metrics** - Kubernetes object metrics

**Metrics Collected:**
- Node resources (CPU, memory, disk)
- Pod metrics
- Network statistics
- Storage usage
- Kubernetes events

**See:** [monitoring/README.md](./monitoring/README.md)

### Traefik Middleware

**Purpose:** Security headers for ingress traffic

**Features:**
- HSTS headers
- Content Security Policy
- XSS Protection
- Frame deny

**See:** [traefik/README.md](./traefik/README.md)

---

## Secrets Management

Secrets are encrypted with **SOPS** before committing to git.

### View Encrypted Secret

```bash
sops -d k3s-manifest/cloudflare/secret.enc.yaml
```

### Edit Encrypted Secret

```bash
sops k3s-manifest/cloudflare/secret.enc.yaml
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
EOF

# 2. Encrypt with SOPS
sops -e /tmp/my-secret.yaml > k3s-manifest/myapp/secret.enc.yaml

# 3. Clean up
rm /tmp/my-secret.yaml

# 4. Commit (encrypted file is safe!)
git add k3s-manifest/myapp/secret.enc.yaml
git commit -m "Add secret for myapp"
```

### Deploy Encrypted Secret

```bash
# Decrypt and apply in one command
sops -d k3s-manifest/cloudflare/secret.enc.yaml | kubectl apply -f -

# Verify
kubectl get secret cloudflare-tunnel-token -n cloudflare
```

---

## Common Operations

### Update Application

```bash
# Edit manifest
vim k3s-manifest/monitoring/grafana-deployment.yaml

# Apply changes
kubectl apply -f k3s-manifest/monitoring/grafana-deployment.yaml

# Watch rollout
kubectl rollout status deployment/grafana -n monitoring
```

### Scale Deployment

```bash
# Imperative
kubectl scale deployment/cloudflared -n cloudflare --replicas=3

# Or edit manifest and apply
```

### View Logs

```bash
# Specific pod
kubectl logs -n monitoring grafana-xxx-yyy -f

# All pods with label
kubectl logs -n monitoring -l app=grafana --tail=50

# Previous container (if crashed)
kubectl logs -n monitoring grafana-xxx-yyy -p
```

### Debug Pod Issues

```bash
# Describe pod for events
kubectl describe pod -n monitoring grafana-xxx-yyy

# Check resource usage
kubectl top pod -n monitoring

# Shell into running pod
kubectl exec -it -n monitoring grafana-xxx-yyy -- /bin/sh

# Check PVC status
kubectl get pvc -n monitoring
```

### Restart Deployment

```bash
# Graceful restart
kubectl rollout restart deployment/grafana -n monitoring

# Force recreate
kubectl delete pod -n monitoring -l app=grafana
```

---

## Accessing Services

### Via Cloudflare Tunnel (External)

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
```

### Via NodePort (Internal Network)

```bash
# Expose service on node IP
kubectl expose deployment grafana -n monitoring --type=NodePort --name=grafana-nodeport

# Get port
kubectl get svc -n monitoring grafana-nodeport
# Access: http://<node-ip>:<nodeport>
```

---

## Troubleshooting

### Pod Stuck in Pending

```bash
# Check events
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - PVC not bound: Check Longhorn is running
# - Insufficient resources: Check node resources
# - Node selector not matched: Check node labels
```

### PVC Not Binding

```bash
# Check PVC status
kubectl get pvc -n <namespace>

# Check Longhorn is healthy
kubectl get pods -n longhorn-system

# Check StorageClass
kubectl get storageclass
```

### Image Pull Errors

```bash
# Check exact error
kubectl describe pod <pod-name> -n <namespace>

# Common issues:
# - Wrong image name/tag
# - Private registry (need imagePullSecrets)
# - Network issue pulling image
```

### Service Not Accessible

```bash
# Check service exists
kubectl get svc -n <namespace>

# Check endpoints
kubectl get endpoints -n <namespace>

# Check pod is running
kubectl get pods -n <namespace>

# Check ingress
kubectl get ingress -n <namespace>
```

### Cloudflare Tunnel Not Working

```bash
# Check pods are running
kubectl get pods -n cloudflare

# Check logs
kubectl logs -n cloudflare -l app=cloudflared --tail=50

# Should see: "Connection registered"

# Check secret exists
kubectl get secret -n cloudflare cloudflare-tunnel-token
```

---

## Best Practices

### Resource Limits

Always set requests and limits:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Health Checks

Use liveness and readiness probes:

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

### Labels

Use consistent labels:

```yaml
metadata:
  labels:
    app: myapp
    component: backend
    environment: production
```

### Namespaces

Organize by function:

- `default` - User workloads
- `monitoring` - Observability tools
- `cloudflare` - External access
- `longhorn-system` - Storage system

### Security

- Don't commit plain text secrets
- Use NetworkPolicies to restrict traffic
- Run as non-root where possible
- Use read-only root filesystems

---

## Adding New Applications

1. **Create directory:**
```bash
mkdir -p k3s-manifest/myapp
```

2. **Create manifests:**
```bash
cd k3s-manifest/myapp

# Namespace
cat > 00-namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
EOF

# Deployment
cat > deployment.yaml << 'EOF'
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

# Service
cat > service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: myapp
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
EOF
```

4. **Deploy:**
```bash
kubectl apply -f k3s-manifest/myapp/
```

---

## Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [K3s Documentation](https://docs.k3s.io/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kubernetes Patterns](https://k8spatterns.io/)

---

**Need more details? Check the README in each application directory!**
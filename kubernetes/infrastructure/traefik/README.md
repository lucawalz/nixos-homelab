# Traefik Ingress Controller

This directory contains the declarative configuration for Traefik, the ingress controller that handles routing and SSL termination for the cluster.

## Components

- `namespace.yaml` - Creates the traefik namespace
- `helmrepository.yaml` - Adds the Traefik Helm repository
- `helmrelease.yaml` - Deploys Traefik via Helm with FluxCD
- `internal-service.yaml` - Additional service for internal cluster access
- `kustomization.yaml` - Kustomize configuration

## Configuration

### Key Features
- **SSL/TLS termination** with Let's Encrypt certificates
- **Internal routing** via `https://traefik.traefik.svc.cluster.local:443`
- **Kubernetes CRD support** for IngressRoute resources
- **Standard Ingress support** for compatibility
- **Persistent storage** for ACME certificates using Longhorn

### Important Settings
- **Email**: Update the ACME email in `helmrelease.yaml`
- **Replicas**: Set to 2 for high availability
- **Storage**: Uses Longhorn for certificate persistence
- **Resources**: Configured with reasonable limits

## Deployment

```bash
# Deploy Traefik
git add kubernetes/infrastructure/traefik/
git commit -m "Add Traefik ingress controller"
git push

# Check deployment
flux get helmreleases -A
kubectl get pods -n traefik
kubectl get svc -n traefik
```

## Usage

### Method 1: Standard Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  rules:
  - host: app.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-service
            port:
              number: 80
  tls:
  - hosts:
    - app.yourdomain.com
```

### Method 2: IngressRoute (Traefik CRD)
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: my-app-route
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`app.yourdomain.com`)
    kind: Rule
    services:
    - name: my-app-service
      port: 80
  tls:
    certResolver: letsencrypt
```

## Integration with Cloudflare Tunnel

Traefik works seamlessly with the Cloudflare Tunnel setup:

1. **Cloudflare Tunnel** routes traffic to `https://traefik.traefik.svc.cluster.local:443`
2. **Traefik** handles internal routing based on Host headers
3. **Your services** become accessible via `https://service.yourdomain.com`

## Troubleshooting

```bash
# Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik

# Check certificate status
kubectl get certificates -A

# Check ingress status
kubectl get ingress -A
kubectl get ingressroute -A

# Access Traefik dashboard (if enabled)
kubectl port-forward -n traefik svc/traefik 8080:8080
# Then visit http://localhost:8080
```
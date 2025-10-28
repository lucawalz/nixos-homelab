# Cloudflare Tunnel Setup

This deploys Cloudflare Tunnel (cloudflared) to securely expose your services through Cloudflare's edge network.

## Prerequisites

1. **Cloudflare account** with a domain
2. **Cloudflare API token** with Zone:Zone:Read, Zone:DNS:Edit permissions
3. **Cloudflare tunnel** created

## Setup Steps

### 1. Create Cloudflare Tunnel

```bash
# Install cloudflared on your local machine
# macOS: brew install cloudflared
# Linux: Download from https://github.com/cloudflare/cloudflared/releases

# Login to Cloudflare
cloudflared tunnel login

# Create a tunnel
cloudflared tunnel create homelab

# This creates ~/.cloudflared/<tunnel-id>.json
# Copy the contents to tunnel-secret.yaml
```

### 2. Configure Secrets

1. **Update `tunnel-secret.yaml`** with your credentials:
   - Copy contents of `~/.cloudflared/<tunnel-id>.json` to `credentials.json`
   - Add your Cloudflare API token

2. **Update `tunnel-config.yaml`**:
   - Replace `your-tunnel-id` with your actual tunnel ID
   - Replace `yourdomain.com` with your actual domain

3. **Encrypt the secret**:
   ```bash
   sops -e tunnel-secret.yaml > tunnel-secret.enc.yaml
   rm tunnel-secret.yaml  # Remove unencrypted version
   ```

4. **Update kustomization.yaml**:
   ```yaml
   resources:
     - tunnel-secret.enc.yaml  # Use encrypted version
   ```

### 3. Deploy

```bash
git add kubernetes/infrastructure/cloudflare/
git commit -m "Add Cloudflare Tunnel via FluxCD"
git push

# Check deployment
flux get helmreleases -A
kubectl get pods -n cloudflare
```

## How it Works

1. **Cloudflare Tunnel** connects to Cloudflare's edge
2. **All traffic** routes through `https://traefik.traefik.svc.cluster.local:443`
3. **Traefik** handles internal routing based on Host headers
4. **Your services** are accessible via `https://service.yourdomain.com`

## DNS Configuration

The tunnel automatically creates DNS records for:
- `*.yourdomain.com` → Your tunnel
- `yourdomain.com` → Your tunnel

## Security Benefits

- **No open ports** - No need to expose ports 80/443 on your router
- **DDoS protection** - Cloudflare handles attacks
- **SSL termination** - Automatic HTTPS certificates
- **Access control** - Use Cloudflare Access for authentication
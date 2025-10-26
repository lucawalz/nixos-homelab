# NixOS Configuration

This directory contains the NixOS system configuration for all nodes in the homelab cluster.

## Files Overview

| File | Purpose |
|------|---------|
| `flake.nix` | Nix flake definition - defines all node configurations |
| `flake.lock` | Locked dependency versions for reproducibility |
| `configuration.nix` | Main system configuration (shared by all nodes) |
| `disko-config.nix` | Automated disk partitioning layout |
| `secrets.nix` | agenix encryption key definitions |
| `secrets/` | Directory containing encrypted secrets |
| `secrets/k3s-token.age` | Encrypted K3s cluster join token |

---

## Architecture

### Node Configurations

This flake defines multiple NixOS configurations, one per node:

- **master** - K3s server node (control plane)
- **worker-1** - K3s agent node (workload)

All nodes share the same `configuration.nix` but receive different `meta.hostname` values via `specialArgs`.

### Configuration Flow

```
flake.nix
  ├── Defines node: master
  │   ├── specialArgs: { meta.hostname = "master"; }
  │   └── modules:
  │       ├── disko-config.nix (disk partitioning)
  │       ├── agenix module (secret decryption)
  │       └── configuration.nix (main config)
  │
  └── Defines node: worker-1
      ├── specialArgs: { meta.hostname = "worker-1"; }
      └── modules: (same as above)
```

---

## Deployment

### Fresh Installation with nixos-anywhere

Deploy master node:
```bash
nixos-anywhere --flake github:lucawalz/nixos-homelab#master root@<master-ip>
```

Deploy worker node:
```bash
nixos-anywhere --flake github:lucawalz/nixos-homelab#worker-1 root@<worker-ip>
```

**What happens:**
1. nixos-anywhere connects to target machine via SSH
2. Disk is partitioned according to `disko-config.nix`
3. NixOS is installed with configuration from git
4. System boots with your configuration
5. K3s starts automatically (server on master, agent on workers)
6. agenix decrypts secrets at boot

### Update Existing System

On the node:
```bash
cd /path/to/nixos-homelab/nixos
git pull
sudo nixos-rebuild switch --flake .#master
```

Or remotely:
```bash
ssh master@<node-ip> "cd /path/to/repo && git pull && sudo nixos-rebuild switch --flake ."
```

### Test Configuration Locally

Before deploying:
```bash
# Build without deploying
nix build .#nixosConfigurations.master.config.system.build.toplevel

# Check for errors
nix flake check

# Show what would be built
nix flake show
```

---

## Configuration Details

### flake.nix

Defines the infrastructure as code:

```nix
{
  description = "NixOS homelab configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = { /* disk partitioning */ };
    agenix = { /* secret management */ };
  };

  outputs = { self, nixpkgs, disko, agenix, ... }: {
    nixosConfigurations = {
      master = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          meta = { hostname = "master"; };  # ← Passed to configuration.nix
        };
        modules = [ /* ... */ ];
      };
      
      worker-1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          meta = { hostname = "worker-1"; };  # ← Different hostname
        };
        modules = [ /* ... */ ];
      };
    };
  };
}
```

### configuration.nix

Main system configuration:

**Key Features:**
- Uses `meta.hostname` from flake for network hostname
- Configures K3s differently based on hostname (server vs agent)
- Sets up user `master` with SSH keys
- Installs required packages (kubectl, helm, sops, age)
- Configures OpenISCSI for Longhorn storage

**K3s Logic:**
```nix
services.k3s = {
  enable = true;
  role = if meta.hostname == "master" then "server" else "agent";
  tokenFile = if meta.hostname == "master"
              then "/var/lib/rancher/k3s/server/node-token"  # Master generates token
              else config.age.secrets.k3s-token.path;        # Worker uses encrypted token
  serverAddr = if meta.hostname == "master" 
               then "" 
               else "https://master:6443";  # Worker connects to master
};
```

### disko-config.nix

Automated disk partitioning:

```nix
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";  # Change if your disk is different
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              start = "1M";
              end = "512M";
              type = "EF00";       # EFI boot partition
              format = "vfat";
              mountpoint = "/boot";
            };
            root = {
              size = "100%";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
```

**Disk Device:** If your machine uses a different disk:
- SATA SSD: `/dev/sda`
- VirtIO (VM): `/dev/vda`
- Second NVMe: `/dev/nvme1n1`

### secrets.nix

Defines who can decrypt each secret:

```nix
let
  # SSH public keys (from /etc/ssh/ssh_host_ed25519_key.pub on each node)
  master = "ssh-ed25519 AAAAC3Nza...";
  worker1 = "ssh-ed25519 AAAAC3Nza...";
  lucawalz = "ssh-ed25519 AAAAC3Nza...";  # Your workstation key
  
  allNodes = [ master worker1 ];
  admins = [ lucawalz ];
in {
  # K3s token can be decrypted by all nodes and admins
  "secrets/k3s-token.age".publicKeys = allNodes ++ admins;
}
```

---

## Secret Management with agenix

### How It Works

1. **Encryption:** Secrets are encrypted with age using SSH keys
2. **Storage:** Encrypted files (`.age`) are committed to git
3. **Decryption:** At boot, agenix decrypts secrets to `/run/agenix/`
4. **Usage:** NixOS config references: `config.age.secrets.<name>.path`

### Working with Secrets

#### Install agenix CLI

On your Mac/workstation:
```bash
# Enable flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Install agenix
nix profile install github:ryantm/agenix

# Set editor
export EDITOR=nano  # or vim, code, etc.
echo 'export EDITOR=nano' >> ~/.zshrc
```

#### Edit Existing Secret

```bash
cd ~/nixos-homelab/nixos

# Opens editor with decrypted content
agenix -e secrets/k3s-token.age

# Make changes, save, exit
# File is automatically re-encrypted
```

#### Create New Secret

1. **Add to `secrets.nix`:**
```nix
"secrets/my-secret.age".publicKeys = allNodes ++ admins;
```

2. **Create and encrypt:**
```bash
agenix -e secrets/my-secret.age
# Type/paste secret content, save, exit
```

3. **Use in `configuration.nix`:**
```nix
age.secrets.my-secret = {
  file = ./secrets/my-secret.age;
  mode = "0400";
  owner = "root";
};

# Reference path: config.age.secrets.my-secret.path
```

4. **Commit:**
```bash
git add nixos/secrets.nix nixos/secrets/my-secret.age
git commit -m "Add new secret"
git push
```

#### Get SSH Keys from Nodes

For `secrets.nix`, you need each node's SSH host key:

```bash
# On each node
ssh master@<node-ip> "cat /etc/ssh/ssh_host_ed25519_key.pub"

# Add to secrets.nix:
master = "ssh-ed25519 AAAAC3Nza... root@master";
```

#### Re-encrypt After Adding New Node

When you add a new worker node:

```bash
# 1. Get new node's SSH key
ssh master@<new-worker-ip> "cat /etc/ssh/ssh_host_ed25519_key.pub"

# 2. Add to secrets.nix
worker2 = "ssh-ed25519 AAAAC3Nza... root@worker-2";
allNodes = [ master worker1 worker2 ];

# 3. Re-encrypt all secrets
cd ~/nixos-homelab/nixos
agenix --rekey

# 4. Commit
git add secrets.nix secrets/
git commit -m "Add worker-2 to secret encryption"
git push
```

#### Quick Reference - Secret Management Commands

```bash
# === agenix (NixOS secrets) ===
cd ~/nixos-homelab/nixos
agenix -e secrets/<secret-name>.age          # Edit secret
agenix --rekey                                # Re-encrypt after adding nodes
sudo nixos-rebuild switch --flake .#master   # Deploy changes

# === SOPS (K8s secrets) ===
cd ~/nixos-homelab
sops k3s-manifest/<app>/secret.enc.yaml                        # Edit secret
sops -d k3s-manifest/<app>/secret.enc.yaml | kubectl apply -f # Deploy to cluster

# === Check decrypted secrets ===
# agenix (on node):
ssh master@<node-ip> "ls -la /run/agenix/"

# SOPS (in cluster):
kubectl get secret -n <namespace>
kubectl get secret <name> -n <namespace> -o yaml
```

---

## Customization

### Add New Node

1. **Add to `flake.nix`:**
```nix
worker-2 = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = {
    meta = { hostname = "worker-2"; };
  };
  modules = [
    disko.nixosModules.disko
    agenix.nixosModules.default
    ./configuration.nix
    ./disko-config.nix
  ];
};
```

2. **Update `secrets.nix`** (see above)

3. **Deploy:**
```bash
nixos-anywhere --flake .#worker-2 root@<worker-2-ip>
```

### Change Disk Device

Edit `disko-config.nix`:
```nix
device = "/dev/sda";  # Change from /dev/nvme0n1
```

### Add System Packages

Edit `configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  neovim
  git
  # Add more packages here
  htop
  tmux
  ripgrep
];
```

### Change Time Zone

Edit `configuration.nix`:
```nix
time.timeZone = "America/New_York";  # Change from Europe/Berlin
```

### Add More Users

Edit `configuration.nix`:
```nix
users.users.alice = {
  isNormalUser = true;
  extraGroups = [ "wheel" ];
  openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3Nza... alice@laptop"
  ];
};
```

### Change K3s Flags

Edit `configuration.nix`:
```nix
services.k3s = {
  # ... existing config ...
  extraFlags = if meta.hostname == "master" then [
    "--write-kubeconfig-mode=0644"
    "--disable=servicelb"
    "--disable=traefik"
    "--disable=local-storage"
    # Add more flags:
    "--cluster-cidr=10.42.0.0/16"
    "--service-cidr=10.43.0.0/16"
  ] else [];
};
```

---

## Troubleshooting

### Build Fails

```bash
# Check for syntax errors
nix flake check

# Show detailed error
nix build .#nixosConfigurations.master.config.system.build.toplevel --show-trace
```

### Can't Decrypt Secrets

```bash
# Check your age key exists
cat ~/.config/sops/age/keys.txt

# If using SSH key, check it's correct
ssh-keygen -l -f ~/.ssh/id_ed25519.pub

# Verify node SSH keys in secrets.nix match actual keys
ssh master@<node-ip> "cat /etc/ssh/ssh_host_ed25519_key.pub"
```

### Wrong Disk Device

Error: `device /dev/nvme0n1 not found`

**Fix:** Check available disks on target:
```bash
ssh root@<target-ip> "lsblk"

# Update disko-config.nix with correct device
```

### K3s Won't Start

```bash
# Check logs on node
ssh master@<node-ip> "sudo journalctl -u k3s -n 50"

# Common issues:
# - Worker can't reach master: check network
# - Wrong token: check agenix decrypted correctly
# - Port conflict: check nothing else using 6443
```

### Configuration Rollback

NixOS keeps old configurations:

```bash
# List available generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous
sudo nixos-rebuild switch --rollback

# Or boot specific generation
sudo /nix/var/nix/profiles/system-42-link/bin/switch-to-configuration switch
```

---

## Advanced Topics

### Garbage Collection

Free up space by removing old generations:

```bash
# Delete generations older than 30 days
sudo nix-collect-garbage --delete-older-than 30d

# Delete all old generations (keep current)
sudo nix-collect-garbage -d

# Optimize store
sudo nix-store --optimise
```

### Binary Cache

Speed up builds using Cachix:

```nix
# In configuration.nix
nix = {
  settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
};
```

### Remote Deployment

Deploy without SSH to target:

```bash
# Build locally
nix build .#nixosConfigurations.master.config.system.build.toplevel

# Copy closure to target
nix copy --to ssh://master@<node-ip> ./result

# Activate on target
ssh master@<node-ip> "sudo /nix/store/...-nixos-system-master-XX.XX/bin/switch-to-configuration switch"
```

### Custom Kernel

```nix
# In configuration.nix
boot.kernelPackages = pkgs.linuxPackages_latest;  # Latest kernel

# Or specific version
boot.kernelPackages = pkgs.linuxPackages_6_6;
```

---

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [NixOS Options Search](https://search.nixos.org/options)
- [Nix Flakes Wiki](https://nixos.wiki/wiki/Flakes)
- [disko Documentation](https://github.com/nix-community/disko)
- [agenix Documentation](https://github.com/ryantm/agenix)
- [K3s NixOS Options](https://search.nixos.org/options?query=services.k3s)

---

## Next Steps

1. **Customize** `configuration.nix` for your needs
2. **Add** more worker nodes to scale
3. **Configure** monitoring and backups
4. **Explore** NixOS modules for your services

**Need help?** Check the main [README](../README.md) or open an issue!

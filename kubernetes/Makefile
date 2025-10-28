# Homelab Kubernetes Management

.PHONY: help deploy-flux bootstrap-gitops check-cluster clean

# Default target
help:
	@echo "Available targets:"
	@echo "  deploy-flux      - Deploy FluxCD to the cluster"
	@echo "  bootstrap-gitops - Bootstrap GitOps repository connection"
	@echo "  check-cluster    - Check cluster connectivity and status"
	@echo "  clean           - Remove FluxCD from cluster"
	@echo "  help            - Show this help message"

# Check if we can connect to the cluster
check-cluster:
	@echo "Checking cluster connectivity..."
	kubectl cluster-info
	@echo "Cluster nodes:"
	kubectl get nodes
	@echo "Current namespaces:"
	kubectl get namespaces

# Deploy FluxCD using Helm
deploy-flux:
	@echo "Deploying FluxCD..."
	cd flux && ./deploy.sh

# Bootstrap GitOps repository connection
bootstrap-gitops:
	@echo "Bootstrapping GitOps repository..."
	@echo "WARNING: Make sure to update the repository URL in flux/bootstrap/gitops-repo.yaml first!"
	kubectl apply -f flux/bootstrap/gitops-repo.yaml
	@echo "GitOps bootstrap applied. Check status with: flux get all -A"

# Clean up FluxCD installation
clean:
	@echo "Removing FluxCD..."
	helm uninstall flux -n flux-system || true
	kubectl delete namespace flux-system || true
	@echo "FluxCD removed"

# Clean up entire cluster (nuclear option)
clean-all:
	@echo "WARNING: This will remove ALL applications from the cluster!"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read
	./cleanup-cluster.sh

# Quick status check
status:
	@echo "FluxCD Status:"
	flux get all -A || echo "FluxCD not installed or flux CLI not available"
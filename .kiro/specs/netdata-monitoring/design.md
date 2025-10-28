# Netdata Monitoring Design Document

## Overview

This design implements Netdata as a complementary real-time monitoring solution for the K3s homelab cluster. Netdata will be deployed as a DaemonSet to provide high-resolution (1-second granularity) metrics collection on each node, while integrating with the existing Prometheus/Grafana stack for unified monitoring. The solution follows established cluster conventions for networking, security, and storage.

## Architecture

### Deployment Model
- **DaemonSet**: Ensures one Netdata instance per cluster node for comprehensive coverage
- **Namespace Isolation**: Dedicated `netdata` namespace separates from core monitoring stack
- **Host Network Access**: Required for accurate system metrics collection
- **Persistent Storage**: Local storage for configuration and metric caching per node

### Integration Points
- **Prometheus Export**: Netdata exposes metrics on `/api/v1/allmetrics?format=prometheus` endpoint
- **Service Discovery**: Kubernetes service enables Prometheus scraping configuration
- **Web Interface**: Centralized access through Traefik ingress with TLS termination
- **Coexistence**: Runs alongside node-exporter without port conflicts

## Components and Interfaces

### Core Components

#### 1. Netdata DaemonSet
- **Image**: `netdata/netdata:stable`
- **Host Access**: Requires hostNetwork, hostPID for system metrics
- **Port Configuration**:
  - 19999: Web interface and API
  - No conflict with node-exporter (9100) or other monitoring
- **Volume Mounts**:
  - `/proc`, `/sys`, `/var/run/docker.sock` for system access
  - `/etc/netdata` for persistent configuration
  - `/var/cache/netdata` for metric caching

#### 2. Service Configuration
- **Type**: ClusterIP for internal access
- **Ports**: 19999 for both web interface and Prometheus metrics
- **Selector**: Targets DaemonSet pods across all nodes
- **Annotations**: Prometheus scraping configuration

#### 3. Ingress Configuration
- **Domain**: `netdata.syslabs.dev` following established pattern
- **TLS**: Let's Encrypt certificate via cert-manager
- **Middleware**: Security headers for enhanced protection
- **Backend**: Routes to Netdata service on port 19999
- **Cloudflare Integration**: Accessible via Traefik at `https://traefik.traefik.svc.cluster.local:443` for Cloudflare tunnel registration

#### 4. Storage Strategy
- **ConfigMap**: Default Netdata configuration with cluster-specific settings
- **PersistentVolume**: Per-node storage for configuration persistence
- **Storage Class**: Longhorn following cluster standards
- **Size**: 5Gi per node for configuration and cache

### Security Configuration

#### RBAC Requirements
- **ServiceAccount**: Dedicated account for Netdata pods
- **ClusterRole**: Read access to nodes, pods, services for Kubernetes metrics
- **Permissions**:
  - `nodes`: get, list, watch
  - `pods`: get, list, watch  
  - `services`: get, list, watch
  - `endpoints`: get, list, watch

#### Security Context
- **Privileged Access**: Required for host system metrics
- **Capabilities**: SYS_PTRACE, SYS_ADMIN for process monitoring
- **Host Access**: hostNetwork and hostPID for accurate metrics

## Data Models

### Metrics Collection
```yaml
# Netdata Configuration Structure
netdata_config:
  global:
    update_every: 1          # 1-second resolution
    memory_mode: dbengine    # Efficient storage
    page_cache_size: 32      # Memory allocation
    dbengine_disk_space: 256 # Disk space per node
  
  web:
    bind_to: "*:19999"       # Listen on all interfaces
    
  plugins:
    proc: yes                # System metrics
    diskspace: yes           # Disk usage
    cgroups: yes             # Container metrics
    kubernetes: yes          # K8s integration
```

### Prometheus Integration
```yaml
# Scrape Configuration for Prometheus
scrape_configs:
  - job_name: 'netdata'
    kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names: ['netdata']
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        regex: 'netdata'
        action: keep
      - source_labels: [__meta_kubernetes_endpoint_node_name]
        target_label: node
    metrics_path: '/api/v1/allmetrics'
    params:
      format: ['prometheus']
```

## Error Handling

### Pod Failure Recovery
- **Restart Policy**: Always restart failed pods
- **Health Checks**: HTTP probes on `/api/v1/info` endpoint
- **Resource Limits**: Prevent resource exhaustion
- **Tolerations**: Run on all nodes including tainted ones

### Storage Issues
- **Fallback Mode**: Memory-only operation if persistent storage fails
- **Cleanup**: Automatic old data purging based on retention settings
- **Monitoring**: Disk usage alerts through Netdata itself

### Network Connectivity
- **Service Mesh**: Kubernetes service provides load balancing
- **DNS Resolution**: Standard cluster DNS for service discovery
- **Port Conflicts**: Validation during deployment to avoid conflicts

## Testing Strategy

### Deployment Validation
- **Pod Status**: Verify DaemonSet pods running on all nodes
- **Service Connectivity**: Test internal service resolution
- **Ingress Access**: Validate external HTTPS access
- **Metrics Export**: Confirm Prometheus can scrape endpoints

### Integration Testing
- **Prometheus Scraping**: Verify metrics appear in Prometheus
- **Grafana Visualization**: Test Netdata metrics in existing dashboards
- **Alert Integration**: Validate alert routing through existing channels
- **Performance Impact**: Monitor resource usage on cluster nodes

### Functional Testing
- **Real-time Metrics**: Verify 1-second resolution data collection
- **Historical Data**: Test metric retention and storage
- **Node Coverage**: Confirm metrics from all cluster nodes
- **Kubernetes Integration**: Validate pod and service discovery

## Implementation Considerations

### Resource Management
- **CPU Limits**: 500m per node to prevent impact
- **Memory Limits**: 512Mi per node for metric storage
- **Disk I/O**: Minimize impact through efficient storage configuration
- **Network**: Optimize metric collection intervals

### Maintenance
- **Updates**: Rolling updates through DaemonSet
- **Configuration**: ConfigMap updates with pod restart
- **Scaling**: Automatic scaling with cluster node additions
- **Backup**: Configuration backup through GitOps

### Monitoring Integration
- **Alerting**: Netdata alerts complement Prometheus alerting
- **Dashboards**: Custom Grafana dashboards for Netdata metrics
- **Correlation**: Cross-reference with existing monitoring data
- **Retention**: Coordinate retention policies between systems
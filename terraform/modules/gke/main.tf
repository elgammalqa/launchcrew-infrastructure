resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_name
  subnetwork = var.subnet_name

  # Cost optimization: Release channel for automatic updates
  release_channel {
    channel = "REGULAR"
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # IP allocation for pods and services
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Master authorized networks - allow all (adjust for production)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  # Network policy
  network_policy {
    enabled  = true
    provider = "PROVIDER_UNSPECIFIED"
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Logging and monitoring (optimized)
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  # Cost optimization: Binary authorization disabled for dev
  binary_authorization {
    evaluation_mode = "DISABLED"
  }

  # Resource labels
  resource_labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Node pool
resource "google_container_node_pool" "primary_nodes" {
  name     = "${var.cluster_name}-node-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  # Autoscaling
  autoscaling {
    min_node_count = var.node_pool_config.min_nodes
    max_node_count = var.node_pool_config.max_nodes
  }

  # Node configuration
  node_config {
    machine_type = var.node_pool_config.machine_type
    disk_size_gb = var.node_pool_config.disk_size_gb
    disk_type    = var.node_pool_config.disk_type

    # Use spot OR preemptible, not both
    preemptible = var.node_pool_config.spot ? false : var.node_pool_config.preemptible
    spot        = var.node_pool_config.spot

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Labels
    labels = {
      environment = var.environment
      managed_by  = "terraform"
    }

    # Tags
    tags = ["gke-node", "${var.cluster_name}-node"]

    # Shielded instance config - disabled for e2-micro spot
    shielded_instance_config {
      enable_secure_boot          = false
      enable_integrity_monitoring = false
    }
  }

  # Management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

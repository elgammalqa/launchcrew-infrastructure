variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
}

variable "pods_range_name" {
  description = "Pods secondary range name"
  type        = string
}

variable "services_range_name" {
  description = "Services secondary range name"
  type        = string
}

variable "node_pool_config" {
  description = "Node pool configuration"
  type = object({
    machine_type = string
    min_nodes    = number
    max_nodes    = number
    disk_size_gb = number
    disk_type    = string
    preemptible  = bool
    spot         = bool
  })
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for GKE master"
  type        = string
  default     = "172.16.0.0/28"
}

variable "enable_autopilot" {
  description = "Enable GKE Autopilot mode"
  type        = bool
  default     = false
}

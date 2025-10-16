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

variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "subnet_cidr" {
  description = "Subnet CIDR range"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Pods secondary CIDR range"
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_cidr" {
  description = "Services secondary CIDR range"
  type        = string
  default     = "10.8.0.0/20"
}

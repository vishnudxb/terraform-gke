# GCP variables

variable "region" {
  default     = "us-east1"
  description = "Region of resources"
}

variable "bucket_name" {
  description = "Name of the google storage bucket"
}

variable "name" {
  default = {
    prod = "gke-prod"
    staging = "gke-staging"
    dev  = "gke-dev"
  }

  description = "VPC for gke service"
}

# Network variables

variable "subnet_cidr" {
  default = {
    prod = "10.10.0.0/24"
    staging = "10.140.0.0/24"
    dev  = "10.240.0.0/24"
  }

  description = "Subnet range for gke service"
}

# Cloud SQL variables

variable "availability_type" {
  default = {
    prod = "REGIONAL"
    staging = "ZONAL"
    dev  = "ZONAL"
  }

  description = "Availability type for HA"
}

variable "sql_instance_size" {
  default     = "db-f1-micro"
  description = "Size of Cloud SQL instances"
}

variable "sql_disk_type" {
  default     = "PD_SSD"
  description = "Cloud SQL instance disk type"
}

variable "sql_disk_size" {
  default     = "10"
  description = "Storage size in GB"
}

variable "sql_require_ssl" {
  default     = "true"
  description = "Enforce SSL connections"
}

variable "sql_master_zone" {
  default     = "b"
  description = "Zone of the Cloud SQL master (a, b, ...)"
}

variable "sql_replica_zone" {
  default     = "c"
  description = "Zone of the Cloud SQL replica (a, b, ...)"
}

variable "sql_connect_retry_interval" {
  default     = 60
  description = "The number of seconds between connect retries."
}

variable "sql_user" {
  default     = "admin"
  description = "Username of the host to access the database"
}

variable "sql_pass" {
  description = "Password of the host to access the database"
}

# GKE variables

variable "min_master_version" {
  default     = "1.13.11"
  description = "Number of nodes in each GKE cluster zone"
}

variable "node_version" {
  default     = "1.13.11"
  description = "Number of nodes in each GKE cluster zone"
}

variable "gke_num_nodes" {
  default = {
    prod = 2
    staging = 1
    dev  = 1
  }

  description = "Number of nodes in each GKE cluster zone"
}

variable "gke_master_user" {
  default     = "admin"
  description = "Username to authenticate with the k8s master"
}

variable "gke_master_pass" {
  description = "Username to authenticate with the k8s master"
}

variable "gke_node_machine_type" {
  default     = "n1-standard-1"
  description = "Machine type of GKE nodes"
}

variable gke_label {
  default = {
    prod = "gke-prod"
    staging = "gke-staging"
    dev  = "gke-dev"
  }

  description = "gke label"
}

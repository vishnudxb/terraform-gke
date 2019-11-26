# GCP variables
variable "region" {
  default     = "us-east1"
  description = "Region of resources"
}

variable "project_name" {
  default = {
    prod = "gke-prod"
    staging = "gke-staging"
    dev  = "gke-dev"
  }

  description = "gke services project"
}

variable "billing_account" {
  description = "Billing account."
}

variable "org_id" {
  description = "Organization account ID."
}

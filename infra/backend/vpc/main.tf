# Create VPC
resource "google_compute_network" "vpc" {
  name                    = "gke-${terraform.workspace}-vpc"
  auto_create_subnetworks = "false"
}

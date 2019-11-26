# Configure the Google Cloud tfstate file location for the terraform project
terraform {
  backend "gcs" {
    bucket = "gke-service"
    prefix = "infra-tfstate"
  }
}

# Configure the Google Cloud tfstate file location for terraform source code
terraform {
  backend "gcs" {
    bucket = "gke-service"
    prefix = "source-tfstate"
  }
}

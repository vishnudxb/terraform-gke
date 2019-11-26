# terraform-gcp
Terraform for Google Cloud

## Initial tooling setup gcloud, kubectl and terraform

#### OS X

```sh
curl -o terraform_0.12.13_darwin_amd64.zip \
 https://releases.hashicorp.com/terraform/0.12.13/terraform_0.12.13_darwin_amd64.zip

unzip terraform_0.12.13_darwin_amd64.zip -d /usr/local/bin/
```

#### Verification

Verify terraform version 0.12.13 or higher is installed:

```sh
terraform version
```

### Deploying kubectl

#### OS X

```sh
brew install kubernetes-cli
```

#### Verification

```sh
kubectl version --client
```

#### Install gcloud sdk

```

curl https://sdk.cloud.google.com | bash  

```

### Authenticate to gcloud

Before configuring gcloud CLI you can check available Zones and Regions nearest to your location

```sh
gcloud auth login
gcloud compute regions list
gcloud compute zones list

```

Follow gcloud init and select default Zone Ex. us-east1

```sh
gcloud init
```

## Creating Google Cloud project and service account for terraform

Best practice to use separate account "technical account" to manage infrastructure, this account can be used in automated code deployment like in TravisCI or any other tool we may choose.

### Set up environment

```sh
export TF_VAR_org_id=46xxxxxxxxx
export TF_VAR_billing_account=010xxxxxxxxxxx
export TF_ADMIN=terraform-admin
export TF_CREDS=~/.config/gcloud/terraform-admin.json
```

> NOTE: value of YOUR_ORG_ID and YOUR_BILLING_ACCOUNT_ID you can find by running

```sh
gcloud organizations list

gcloud beta billing accounts list
```

### Create the Terraform Admin Project

Create a new project and link it to our billing account

```sh
gcloud projects create ${TF_ADMIN} --organization ${TF_VAR_org_id} --set-as-default


gcloud beta billing projects link ${TF_ADMIN} --billing-account ${TF_VAR_billing_account}

```

### Create the Terraform service account

Create the service account in the Terraform admin project and download the JSON credentials:

```sh
gcloud iam service-accounts create terraform --display-name "Terraform admin account"

gcloud iam service-accounts keys create ${TF_CREDS} --iam-account terraform@${TF_ADMIN}.iam.gserviceaccount.com

```

Grant the service account permission to view the Admin Project and manage Cloud Storage

```sh
gcloud projects add-iam-policy-binding ${TF_ADMIN} \
 --member serviceAccount:terraform@${TF_ADMIN}.iam.gserviceaccount.com  --role roles/viewer


 gcloud projects add-iam-policy-binding ${TF_ADMIN} \
  --member serviceAccount:terraform@${TF_ADMIN}.iam.gserviceaccount.com  --role roles/storage.admin

```

Enabled API for newly created projects

```sh
gcloud services enable cloudresourcemanager.googleapis.com && \
gcloud services enable cloudbilling.googleapis.com && \
gcloud services enable iam.googleapis.com && \
gcloud services enable compute.googleapis.com && \
gcloud services enable sqladmin.googleapis.com && \
gcloud services enable container.googleapis.com
```

### Add organization/folder-level permissions

Grant the service account permission to create projects and assign billing accounts

```sh
gcloud organizations add-iam-policy-binding ${TF_VAR_org_id} \
 --member serviceAccount:terraform@${TF_ADMIN}.iam.gserviceaccount.com \
 --role roles/resourcemanager.projectCreator


 gcloud organizations add-iam-policy-binding ${TF_VAR_org_id} \
 --member serviceAccount:terraform@${TF_ADMIN}.iam.gserviceaccount.com \
 --role roles/billing.user

```

## Creating backend storage to tfstate file in Cloud Storage

Terraform stores the state about infrastructure and configuration by default local file "terraform.tfstate. State is used by Terraform to map resources to configuration, track metadata.

Terraform allows state file to be stored remotely, which works better in a team environment or automated deployments.
We will used Google Storage and create new bucket where we can store state files.

Create the remote back-end bucket in Cloud Storage for storage of the terraform.tfstate file

```sh
gsutil mb -p ${TF_ADMIN} -l us-east1 gs://${TF_ADMIN}
```

Enable versioning for said remote bucket:

```sh
gsutil versioning set on gs://${TF_ADMIN}
```

Configure your environment for the Google Cloud terraform provider

```sh
export GOOGLE_APPLICATION_CREDENTIALS=${TF_CREDS}
```

## Setting up separate projects for Development and Production environments

In order to segregate Development environment we will use Google cloud projects that allows us to segregate infrastructure but maintain same time same code base for terraform.

Terraform allow us to use separate tfstate file for different environment by using terraform functionality workspaces.
Let's see current file structure

```sh
.
├── backend.tf
├── main.tf
├── outputs.tf
├── terraform.tfvars
└── variables.tf
```

* 1st step is to keep sensitive information outside external git repository.Best practice is to create terraform.tfvars and keep sensitive information and add .tfvars to .gitignore

```sh
.gitignore
*.tfstate
*.tfstate.backup
*.tfvars
.terraform
tfplan
```

* Create terraform.tfvars file in project folder and replace "XXXXXX" with proper data. In our case tfvars files data is reference in variables.tf where we keep variables for main.tf

```sh
billing_account     = "XXXXXX-XXXXXX-XXXXXX"
org_id              = "XXXXXXXXXXX"
```

* backend.tf allows us to use newly created Google storage bucket to keep our tfstate files.

```go
terraform {
  backend "gcs" {
    bucket = "gke-service"
    prefix = "infra-tfstate"
  }
}
```

* Variable used in terraform main.tf file

```go
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

  description = "The NAME of the Google Cloud project"
}

variable "billing_account" {
  description = "Billing account STRING."
}

variable "org_id" {
  description = "Organisation account NR."
}
```

* Outputs, once terraform will deploy new infrastructure we will need some outputs that we can reuse for GKE and SQL setup

```go
# project creation output
output "project_id" {
  value = "${google_project.project.project_id}"
}
```

* Finally main source of the gcloud project creation

```go
provider "google" {
  version = "~> 2.5"
  region  = "${var.region}"
}

provider "random" {}

resource "random_id" "id" {
  byte_length = 2
  prefix      = "${var.project_name[terraform.workspace]}-"
}

resource "google_project" "project" {
  name            = "${var.project_name[terraform.workspace]}"
  project_id      = "${random_id.id.hex}"
  billing_account = "${var.billing_account}"
  org_id          = "${var.org_id}"
}

module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "4.0.0"

  project_id = "${google_project.project.project_id}"

  activate_apis = [
    "bigquery-json.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "containerregistry.googleapis.com",
    "deploymentmanager.googleapis.com",
    "dns.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "oslogin.googleapis.com",
    "pubsub.googleapis.com",
    "replicapool.googleapis.com",
    "replicapoolupdater.googleapis.com",
    "resourceviews.googleapis.com",
    "servicemanagement.googleapis.com",
    "sql-component.googleapis.com",
    "sqladmin.googleapis.com",
    "storage-api.googleapis.com",
  ]
}
```

### Initialize and pull terraform cloud specific dependencies

Terraform uses modular setup and in order to download specific plugin for cloud provider, terraform will need to be 1st initiated.

```sh
terraform init
```

### Workspace creation for dev and prod

Once we have our project code and our tfvar secretes secure we can create workspaces for terraform

> NOTE: in below example we will use only dev workspace but we can use both following same logic

* Create dev workspace

```sh
terraform workspace new dev
```

* List available workspaces

```sh
terraform workspace list
```

* Switch between workspaces

```sh
terraform workspace select dev
```

### Terraform plan

Terraform plan will simulate what changes terraform will be done on cloud provider

```sh
terraform plan
```

### Apply terraform plan for selected environment

```sh
terraform apply
```

## Creating Kubernetes cluster on GKE and PostgreSQL on Cloud SQL

Once we have project ready for dev and prod we can move into deploying our gke and sql infrastructure.

Code structure

```sh
.
├── backend
│   ├── firewall
│   │   ├── main.tf
│   │   └── variables.tf
│   ├── subnet
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── vpc
│       ├── main.tf
│       └── outputs.tf
├── backend.tf
├── cloudsql
│   ├── main.tf
│   ├── outputs.tf
│   └── variables.tf
├── gke
│   ├── main.tf
│   ├── outputs.tf
│   └── variables.tf
├── main.tf
├── outputs.tf
└── variables.tf
```

Deploy our infrastructure, noticeable differences between prod and dev workspaces we can find in the terraform files.

* dev - single instance of PostgreSQL without replication and read replica
* staging - single instance of PostgreSQL without replication and read replica
* prod - single instance in multi AZ for high availablity and additional one read replica for PostgreSQL

* dev - single kubernetes node will be added to GKE
* staging - single kubernetes node will be added to GKE
* prod - two nodes will be created and added to kubernetes GKE

Its best to use modules for every segment Networking(vpc, subnets and firewall), cloudsql and gke.

main.tf

```go
# Configure the Google Cloud provider

data "terraform_remote_state" "project_id" {
  backend   = "gcs"
  workspace = "${terraform.workspace}"

  config {
    bucket = "${var.bucket_name}"
    prefix = "terraform-project"
  }
}

provider "google" {
  version = "~> 2.5"
  project = "${data.terraform_remote_state.project_id.project_id}"
  region  = "${var.region}"
}

module "vpc" {
  source = "./backend/vpc"
}

module "subnet" {
  source      = "./backend/subnet"
  region      = "${var.region}"
  vpc_name     = "${module.vpc.vpc_name}"
  subnet_cidr = "${var.subnet_cidr}"
}

module "firewall" {
  source        = "./backend/firewall"
  vpc_name       = "${module.vpc.vpc_name}"
  ip_cidr_range = "${module.subnet.ip_cidr_range}"
}

module "cloudsql" {
  source                     = "./cloudsql"
  region                     = "${var.region}"
  availability_type          = "${var.availability_type}"
  sql_instance_size          = "${var.sql_instance_size}"
  sql_disk_type              = "${var.sql_disk_type}"
  sql_disk_size              = "${var.sql_disk_size}"
  sql_require_ssl            = "${var.sql_require_ssl}"
  sql_master_zone            = "${var.sql_master_zone}"
  sql_connect_retry_interval = "${var.sql_connect_retry_interval}"
  sql_replica_zone           = "${var.sql_replica_zone}"
  sql_user                   = "${var.sql_user}"
  sql_pass                   = "${var.sql_pass}"
}

module "gke" {
  source                = "./gke"
  region                = "${var.region}"
  min_master_version    = "${var.min_master_version}"
  node_version          = "${var.node_version}"
  gke_num_nodes         = "${var.gke_num_nodes}"
  vpc_name              = "${module.vpc.vpc_name}"
  subnet_name           = "${module.subnet.subnet_name}"
  gke_master_user       = "${var.gke_master_user}"
  gke_master_pass       = "${var.gke_master_pass}"
  gke_node_machine_type = "${var.gke_node_machine_type}"
  gke_label             = "${var.gke_label}"
}
```

All variables that is consumed by modules I keep in single variable.tf file.

We will use same google storage bucket but with different prefix not to conflict with project creation terraform plan.

```go
# Configure the Google Cloud tfstate file location
terraform {
  backend "gcs" {
    bucket = "gke-service"
    prefix = "source-tfstate"
  }
}
```

### Running terraform changes for infrastructure

As we are in separate code base will need to follow same sequence as in project creation.

> NOTE: Just make sure we have new terraform.tfvars

```sh
bucket_name         = "gke-service"
gke_master_pass     = "your-gke-password"
sql_pass            = "your-sql-password"
```

* Initialize and pull terraform cloud specific dependencies

```sh
terraform init
```

* Create dev workspace

```sh
terraform workspace new dev
```

* List available workspaces

```sh
terraform workspace list
```

* Switch between workspaces

```sh
terraform workspace select dev
```

* Terraform plan will simulate what changes terraform will be done on cloud provider

```sh
terraform plan
```

* Apply terraform

```sh
terraform apply
```

* To check what terraform deployed use

```sh
terraform show
```

* Once test is completed you can remove "destroy" all buildup infrastructure.

```sh
terraform destroy -auto-approve
```

## Terraform Tips

* Refresh terraform

```sh
terraform refresh
```

* List and show terraform state file

```sh
▶ tf state list
google_project.project
random_id.id
module.project-services.google_project_service.project_services["bigquery-json.googleapis.com"]
module.project-services.google_project_service.project_services["compute.googleapis.com"]
module.project-services.google_project_service.project_services["container.googleapis.com"]
module.project-services.google_project_service.project_services["containerregistry.googleapis.com"]
module.project-services.google_project_service.project_services["deploymentmanager.googleapis.com"]
module.project-services.google_project_service.project_services["dns.googleapis.com"]
module.project-services.google_project_service.project_services["logging.googleapis.com"]
module.project-services.google_project_service.project_services["monitoring.googleapis.com"]
module.project-services.google_project_service.project_services["oslogin.googleapis.com"]
module.project-services.google_project_service.project_services["pubsub.googleapis.com"]
module.project-services.google_project_service.project_services["replicapool.googleapis.com"]
module.project-services.google_project_service.project_services["replicapoolupdater.googleapis.com"]
module.project-services.google_project_service.project_services["resourceviews.googleapis.com"]
module.project-services.google_project_service.project_services["servicemanagement.googleapis.com"]
module.project-services.google_project_service.project_services["sql-component.googleapis.com"]
module.project-services.google_project_service.project_services["sqladmin.googleapis.com"]
module.project-services.google_project_service.project_services["storage-api.googleapis.com"]

▶ tf state show google_project.project
# google_project.project:
resource "google_project" "project" {
    app_engine          = []
    auto_create_network = true
    billing_account     = "0xxx-xxx-xxx"
    id                  = "gke-dev-xxxx"
    name                = "gke-dev"
    number              = "1xxxxx"
    org_id              = "xxxx"
    project_id          = "gke-dev-xxxx"
}

```

* Use tflint to check syntax of the tf files

```sh
tflint
```

* Destroy only selected module Ex.

```sh
terraform destroy -target=module.cloudsql
```

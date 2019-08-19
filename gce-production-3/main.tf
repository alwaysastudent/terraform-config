variable "env" {
  default = "production"
}

variable "index" {
  default = 3
}

variable "k8s_default_namespace" {
  default = "gce-production-3"
}

variable "project" {
  default = "travis-ci-prod-3"
}

terraform {
  backend "s3" {
    bucket         = "travis-terraform-state"
    key            = "terraform-config/gce-production-3.tfstate"
    region         = "us-east-1"
    encrypt        = "true"
    dynamodb_table = "travis-terraform-state"
  }
}

provider "google" {
  project = "${var.project}"
  region  = "us-central1"
}

provider "aws" {}

provider "kubernetes" {
  # NOTE: For imports, config_context needs to be hardcoded and host/client/cluster needs to be commented out.

  #config_context = "gke_travis-ci-prod-3_us-central1_gce-production-3"

  host                   = "${module.gke_cluster_1.host}"
  client_certificate     = "${module.gke_cluster_1.client_certificate}"
  client_key             = "${module.gke_cluster_1.client_key}"
  cluster_ca_certificate = "${module.gke_cluster_1.cluster_ca_certificate}"
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    bucket         = "travis-terraform-state"
    key            = "terraform-config/gce-production-net-3.tfstate"
    region         = "us-east-1"
    dynamodb_table = "travis-terraform-state"
  }
}

module "aws_iam_user_s3_com" {
  source = "../modules/aws_iam_user_s3"

  iam_user_name  = "worker-gce-${var.env}-${var.index}-com"
  s3_bucket_name = "build-trace.travis-ci.com"
}

module "aws_iam_user_s3_org" {
  source = "../modules/aws_iam_user_s3"

  iam_user_name  = "worker-gce-${var.env}-${var.index}-org"
  s3_bucket_name = "build-trace.travis-ci.org"
}

module "gce_worker_group" {
  source = "../modules/gce_worker_group"

  aws_com_id            = "${module.aws_iam_user_s3_com.id}"
  aws_com_secret        = "${module.aws_iam_user_s3_com.secret}"
  aws_com_trace_bucket  = "${module.aws_iam_user_s3_com.bucket}"
  aws_org_id            = "${module.aws_iam_user_s3_org.id}"
  aws_org_secret        = "${module.aws_iam_user_s3_org.secret}"
  aws_org_trace_bucket  = "${module.aws_iam_user_s3_org.bucket}"
  env                   = "${var.env}"
  index                 = "${var.index}"
  k8s_default_namespace = "${var.k8s_default_namespace}"
  project               = "${var.project}"
  region                = "us-central1"
}

module "gke_cluster_1" {
  source                = "../modules/gke_cluster"
  cluster_name          = "gce-production-3"
  pool_name             = "gce-production-3"
  gke_network           = "${data.terraform_remote_state.vpc.gce_network_main}"
  gke_subnetwork        = "${data.terraform_remote_state.vpc.gce_subnetwork_gke_cluster}"
  k8s_default_namespace = "${var.k8s_default_namespace}"
  k8s_min_node_count    = 4
  k8s_max_node_count    = 50
}

output "workers_service_account_emails" {
  value = ["${module.gce_worker_group.workers_service_account_emails}"]
}

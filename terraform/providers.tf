# App remote backend
# Remote backend for storing Terraform state for this deployment (the app)
terraform {
  backend "s3" {
    bucket         = "seliot-terraform-state-bucket-arpio1"
    key            = "xyz_app_poc/terraform.tfstate"
    dynamodb_table = "terraform-lock"
    region         = "us-east-1"
    encrypt        = true
  }
}

# Infrastructure remote backend
# We use the remote backend state to retrieve the infrastructure outputs created by xyz_infra_poc
# We must pull from the appropriate workspace that corresponds to the environment stage we are deploying
# Terraform is weird and won't accept a `workspace` value in config, so instead we use it to form the S3 key
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "seliot-terraform-state-bucket-arpio1"
    key    = "env:/${var.workspace}/xyz_infra_poc/terraform.tfstate"
    region = "us-east-1"
  }
}

# Get the AWS Region from the infrastructure remote backend state
locals {
  region = data.terraform_remote_state.infra.outputs.aws_region
}

# This tells Terraform which AWS region to look in for the EKS cluster
provider "aws" {
  region = local.region
}

# Using the cluster name from the remote backend state, we retrieve data about the EKS cluster
data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.infra.outputs.eks_cluster_name
}

# Data provider for cluster auth, used to get token
data "aws_eks_cluster_auth" "cluster_auth" {
  name = data.terraform_remote_state.infra.outputs.eks_cluster_name
}

# Define the kubernetes provider using the data from the EKS cluster
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster_auth.token
}


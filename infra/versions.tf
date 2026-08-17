# Terraform version constraint and required providers.
# Pinning prevents surprise breaking changes when a new provider major ships.
terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.58"
    }
  }
  backend "s3" {
    bucket       = "toleflaco-terraform-state-2026"
    key          = "envs/dev/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}
# AWS provider configuration. Region matches where the rest of the task-manager infra lives.
provider "aws" {
  region = "eu-west-1"
}

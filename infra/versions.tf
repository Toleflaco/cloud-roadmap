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
}

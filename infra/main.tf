# AWS provider configuration. Region matches where the rest of the task-manager infra lives.
provider "aws" {
  region = "eu-west-1"
}

# Trivial S3 bucket to exercise the full init/plan/apply/destroy lifecycle end-to-end.
# Deliberately minimal: no versioning, no policies, no encryption config.
# The point of this exercise is the workflow, not the bucket.
resource "aws_s3_bucket" "test" {
  bucket = "terraform-test-toleflaco-2026"

  tags = {
    Purpose   = "Terraform learning exercise S10"
    ManagedBy = "Terraform"
  }
}

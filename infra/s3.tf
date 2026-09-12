resource "aws_s3_bucket" "task_manager_uploads" {
  bucket = "toleflaco-task-manager-uploads-2026"
  tags = {
    Project     = "task-manager"
    Environment = "learning"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "task_manager_uploads" {
  bucket = aws_s3_bucket.task_manager_uploads.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "task_manager_uploads" {
  bucket                  = aws_s3_bucket.task_manager_uploads.bucket
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

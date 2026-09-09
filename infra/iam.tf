
resource "aws_iam_role" "ec2_task_manager" {
  name               = "task-manager-ec2-role"
  description        = "IAM Role attached to task-manager-ec2 instance. Grants read/write access to toleflaco-task-manager-uploads-2026 S3 bucket via task-manager-s3-uploads-rw policy."
  assume_role_policy = <<-POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
POLICY
  tags = {
    Project = "task-manager"
  }
}

resource "aws_iam_policy" "s3_uploads_rw" {
  name        = "task-manager-s3-uploads-rw"
  description = "Allow PutObject and GetObject on toleflaco-task-manager-uploads-2026 bucket. Used by EC2 IAM Role for task-manager-api."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListAllMyBuckets"
        Effect   = "Allow"
        Action   = "s3:ListAllMyBuckets"
        Resource = "*"
      },
      {
        Sid      = "ListSpecificBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::toleflaco-task-manager-uploads-2026"
      },
      {
        Sid    = "ReadWriteObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::toleflaco-task-manager-uploads-2026/*"
      }
    ]
  })
  tags = {
    Project = "task-manager"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_task_manager_s3_uploads_rw" {
  role       = aws_iam_role.ec2_task_manager.name
  policy_arn = aws_iam_policy.s3_uploads_rw.arn
}

resource "aws_iam_instance_profile" "ec2_task_manager" {
  name = "task-manager-ec2-role"
  role = aws_iam_role.ec2_task_manager.name
}

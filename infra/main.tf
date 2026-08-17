resource "aws_vpc" "main" {
  tags = {
    Name = "task-manager-vpc"
  }
  cidr_block = "10.0.0.0/16"
}


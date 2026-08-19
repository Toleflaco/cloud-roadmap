resource "aws_vpc" "main" {
  tags = {
    Name = "task-manager-vpc"
  }
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "private_1a" {
  vpc_id                          = "vpc-0d36eccf71cddeda7"
  cidr_block                      = "10.0.128.0/20"
  availability_zone               = "eu-west-1a"
  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = false
  tags = {
    Name = "task-manager-subnet-private1-eu-west-1a"
  }
}

resource "aws_subnet" "private_1b" {
  vpc_id                          = "vpc-0d36eccf71cddeda7"
  cidr_block                      = "10.0.144.0/20"
  availability_zone               = "eu-west-1b"
  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = false
  tags = {
    Name = "task-manager-subnet-private2-eu-west-1b"
  }
}

resource "aws_subnet" "public_1a" {
  vpc_id                          = "vpc-0d36eccf71cddeda7"
  cidr_block                      = "10.0.0.0/20"
  availability_zone               = "eu-west-1a"
  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = false
  tags = {
    Name = "task-manager-subnet-public1-eu-west-1a"
  }
}

resource "aws_subnet" "public_1b" {
  vpc_id                          = "vpc-0d36eccf71cddeda7"
  cidr_block                      = "10.0.16.0/20"
  availability_zone               = "eu-west-1b"
  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = false
  tags = {
    Name = "task-manager-subnet-public2-eu-west-1b"
  }
}

resource "aws_internet_gateway" "task_manager" {
  vpc_id = "vpc-0d36eccf71cddeda7"
  tags = {
    Name = "task-manager-igw"
  }
}

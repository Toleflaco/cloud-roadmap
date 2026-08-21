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

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "task-manager-rtb-public"
  }
}

resource "aws_route" "public_to_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.task_manager.id
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public.id
}



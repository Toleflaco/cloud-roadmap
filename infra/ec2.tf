resource "aws_instance" "task_manager_ec2" {
  ami           = "ami-04df7d76c1b804451"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_1a.id
  key_name      = aws_key_pair.task_manager_key.key_name
  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]
  iam_instance_profile = aws_iam_instance_profile.ec2_task_manager.name
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  root_block_device {
    delete_on_termination = true
    encrypted             = true
  }
  tags = {
    Name = "task-manager-ec2"
  }
}

resource "aws_key_pair" "task_manager_key" {
  key_name   = "task-manager-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ1Zisc7toeYK6rk0uSAv5lfUm1WxKkJIpWiC4dnxyPG"
}

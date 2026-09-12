resource "aws_db_subnet_group" "task_manager" {
  name        = "task-manager-db-subnet-group"
  description = "Private subnets in eu-west-1a and eu-west-1b for task-manager RDS"
  subnet_ids = [
    aws_subnet.private_1a.id,
    aws_subnet.private_1b.id
  ]
}

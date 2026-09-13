resource "aws_db_subnet_group" "task_manager" {
  name        = "task-manager-db-subnet-group"
  description = "Private subnets in eu-west-1a and eu-west-1b for task-manager RDS"
  subnet_ids = [
    aws_subnet.private_1a.id,
    aws_subnet.private_1b.id
  ]
}
resource "aws_db_instance" "task_manager_db" {
  identifier                 = "task-manager-db"
  engine                     = "postgres" # required
  engine_version             = "18.3"
  username                   = "postgres"
  instance_class             = "db.t4g.micro"
  publicly_accessible        = false
  db_subnet_group_name       = aws_db_subnet_group.task_manager.name
  vpc_security_group_ids     = [aws_security_group.db.id]
  allocated_storage          = 20
  storage_encrypted          = true
  backup_retention_period    = 1
  copy_tags_to_snapshot      = true
  deletion_protection        = true
  skip_final_snapshot        = true
  auto_minor_version_upgrade = true
  ca_cert_identifier         = "rds-ca-rsa2048-g1"
  tags = {
    Project = "task-manager"
  }
}

variable "vpc_id" {}
variable "private_subnet_ids" { type = list(string) }
variable "eks_node_sg_id" {}

resource "aws_security_group" "rds" {
  name   = "project-bedrock-rds-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "project-bedrock-db-subnets"
  subnet_ids = var.private_subnet_ids
}

resource "random_password" "mysql" {
  length  = 20
  special = false
}

resource "random_password" "postgres" {
  length  = 20
  special = false
}

resource "aws_secretsmanager_secret" "mysql" {
  name = "bedrock/catalog-mysql"
}

resource "aws_secretsmanager_secret_version" "mysql" {
  secret_id     = aws_secretsmanager_secret.mysql.id
  secret_string = jsonencode({ username = "catalog_admin", password = random_password.mysql.result })
}

resource "aws_secretsmanager_secret" "postgres" {
  name = "bedrock/orders-postgres"
}

resource "aws_secretsmanager_secret_version" "postgres" {
  secret_id     = aws_secretsmanager_secret.postgres.id
  secret_string = jsonencode({ username = "orders_admin", password = random_password.postgres.result })
}

resource "aws_db_instance" "catalog_mysql" {
  identifier              = "bedrock-catalog-mysql"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  db_name                 = "catalog"
  username                = "catalog_admin"
  password                = random_password.mysql.result
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  multi_az                = false
  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 7
}

resource "aws_db_instance" "orders_postgres" {
  identifier              = "bedrock-orders-postgres"
  engine                  = "postgres"
  engine_version          = "16"
  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  db_name                 = "orders"
  username                = "orders_admin"
  password                = random_password.postgres.result
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  multi_az                = false
  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 7
}

output "mysql_endpoint" { value = aws_db_instance.catalog_mysql.endpoint }
output "postgres_endpoint" { value = aws_db_instance.orders_postgres.endpoint }
output "mysql_secret_arn" { value = aws_secretsmanager_secret.mysql.arn }
output "postgres_secret_arn" { value = aws_secretsmanager_secret.postgres.arn }
output "rds_security_group_id" { value = aws_security_group.rds.id }

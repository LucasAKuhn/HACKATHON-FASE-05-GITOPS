resource "aws_db_subnet_group" "private_db" {
  name       = "solidarytech-private-db"
  subnet_ids = var.private_subnets
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

resource "aws_security_group" "db_sg" {
  name        = "solidarytech-db-sg"
  description = "Security Group para o RDS"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL do EKS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "solidarytech-db"
  allocated_storage      = 20
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  username               = "postgres"
  password               = var.db_password
  skip_final_snapshot    = true
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.private_db.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  monitoring_interval    = 0
}

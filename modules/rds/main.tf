terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
  }
}

locals {
  allowed_cidrs = length(var.allowed_cidr_blocks) > 0 ? var.allowed_cidr_blocks : [var.vpc_cidr_block]
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnets"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.identifier}-subnets"
  })
}

resource "aws_security_group" "this" {
  name        = "${var.identifier}-sg"
  description = "Database access control"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = local.allowed_cidrs
    content {
      description = "DB access"
      from_port   = var.port
      to_port     = var.port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-sg"
  })
}

resource "aws_db_instance" "this" {
  identifier              = var.identifier
  engine                  = var.engine
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  db_name                 = var.db_name
  username                = var.username
  password                = var.password
  port                    = var.port
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.this.id]
  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  maintenance_window      = var.maintenance_window
  deletion_protection     = var.deletion_protection
  storage_encrypted       = var.storage_encrypted
  publicly_accessible     = false
  skip_final_snapshot     = var.skip_final_snapshot
  apply_immediately       = var.apply_immediately

  tags = merge(var.tags, {
    Name = var.identifier
  })
}

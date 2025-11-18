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

resource "aws_security_group" "this" {
  name        = "${var.name}-redis-sg"
  description = "ElastiCache access control"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = local.allowed_cidrs
    content {
      description = "Redis access"
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
    Name = "${var.name}-redis-sg"
  })
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis-subnets"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name}-redis-subnets"
  })
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = var.name
  description                = "Redis replication group for ${var.name}"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  number_cache_clusters      = var.num_cache_clusters
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [aws_security_group.this.id]
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  automatic_failover_enabled = var.num_cache_clusters > 1
  maintenance_window         = var.maintenance_window
  port                       = var.port
  parameter_group_name       = var.parameter_group_name
  apply_immediately          = var.apply_immediately
  multi_az_enabled           = var.num_cache_clusters > 1
  auth_token                 = var.auth_token != "" ? var.auth_token : null

  tags = merge(var.tags, {
    Name = var.name
  })
}

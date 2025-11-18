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
  public_subnet_count  = length(var.public_subnet_cidrs)
  private_subnet_count = length(var.private_subnet_cidrs)
}

data "aws_region" "current" {}

# VPC
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = merge(var.tags, {
    Name = "main"
  })
}

# Declare the data source
data "aws_availability_zones" "available" {
  state = "available"
}

# Create public subnets
resource "aws_subnet" "public" {
  count                   = local.public_subnet_count
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  tags = merge(var.tags, {
    Name = "public-subnet-${count.index + 1}"
  })
}

# Create private subnets
resource "aws_subnet" "private" {
  count                   = local.private_subnet_count
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  cidr_block              = var.private_subnet_cidrs[count.index]
  map_public_ip_on_launch = false
  tags = merge(var.tags, {
    Name = "private-subnet-${count.index + 1}"
  })
}

# IG
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "main-igw"
  })
}

# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(var.tags, {
    Name = "public-rt"
  })
}

# Route Table Association
resource "aws_route_table_association" "public_rt_assoc" {
  count          = local.public_subnet_count
  route_table_id = aws_route_table.public_rt.id
  subnet_id      = aws_subnet.public[count.index].id
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = merge(var.tags, {
    Name = "private-rt"
  })
}

# Private Route Table Association
resource "aws_route_table_association" "private_rt_assoc" {
  count          = local.private_subnet_count
  route_table_id = aws_route_table.private_rt.id
  subnet_id      = aws_subnet.private[count.index].id
}

# aws_eip
resource "aws_eip" "eip_nat_gw" {
  domain = "vpc"
  tags = merge(var.tags, {
    Name = "NAT Gateway EIP"
  })
}

# Create a NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.eip_nat_gw.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.igw]
  tags = merge(var.tags, {
    Name = "NAT Gateway"
  })
}

##### Optional Network Enhancements #####

# Flow logs -> CloudWatch Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = var.flow_logs_log_group_name != "" ? var.flow_logs_log_group_name : "/aws/vpc/${aws_vpc.main.id}/flow-logs"
  retention_in_days = var.flow_logs_retention_in_days
  tags = merge(var.tags, {
    Name = "vpc-flow-logs"
  })
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${replace(aws_vpc.main.id, "-", "")}-flow-logs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = merge(var.tags, {
    Name = "vpc-flow-logs"
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${aws_vpc.main.id}-flow-logs"
  role = aws_iam_role.flow_logs[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "vpc" {
  count = var.enable_flow_logs ? 1 : 0

  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  log_destination_type = "cloud-watch-logs"
  log_group_name       = aws_cloudwatch_log_group.flow_logs[0].name
  iam_role_arn         = aws_iam_role.flow_logs[0].arn
  tags = merge(var.tags, {
    Name = "vpc-flow-logs"
  })
}

# Gateway endpoints
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id            = aws_vpc.main.id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  route_table_ids   = [aws_route_table.public_rt.id, aws_route_table.private_rt.id]

  tags = merge(var.tags, {
    Name = "s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_dynamodb_endpoint ? 1 : 0

  vpc_id            = aws_vpc.main.id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  route_table_ids   = [aws_route_table.public_rt.id, aws_route_table.private_rt.id]

  tags = merge(var.tags, {
    Name = "dynamodb-endpoint"
  })
}

# Interface endpoints for SSM
resource "aws_security_group" "interface_endpoints" {
  count = var.enable_ssm_endpoint ? 1 : 0

  name        = "${aws_vpc.main.id}-ssm-endpoints"
  description = "Allow interface endpoint traffic for SSM"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "TLS from within the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "ssm-endpoints"
  })
}

resource "aws_vpc_endpoint" "ssm" {
  count = var.enable_ssm_endpoint ? 1 : 0

  vpc_id              = aws_vpc.main.id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.interface_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "ssm-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssm_messages" {
  count = var.enable_ssm_endpoint ? 1 : 0

  vpc_id              = aws_vpc.main.id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.interface_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "ssmmessages-endpoint"
  })
}

resource "aws_vpc_endpoint" "ec2_messages" {
  count = var.enable_ssm_endpoint ? 1 : 0

  vpc_id              = aws_vpc.main.id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.interface_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "ec2messages-endpoint"
  })
}



#### Outputs ####
output "availability_zones" {
  value = data.aws_availability_zones.available.names
}

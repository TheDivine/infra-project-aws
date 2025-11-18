variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "aws_profile" {
  description = "Shared credentials profile name"
  type        = string
  default     = "default"
}

variable "vpc_cidr" {
  description = "Define VPC CIDR Block"
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.10.21.0/24", "10.10.22.0/24", "10.10.24.0/24", "10.10.25.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.10.23.0/24"]
}


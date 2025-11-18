variable "vpc_cidr" {
  description = "Define VPC CIDR Block"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.4.0/24", "10.0.5.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24"]
}

variable "tags" {
  description = "Common tags applied to every resource in this module"
  type        = map(string)
  default     = {}
}

variable "enable_s3_endpoint" {
  description = "Create a gateway VPC endpoint for S3"
  type        = bool
  default     = false
}

variable "enable_dynamodb_endpoint" {
  description = "Create a gateway VPC endpoint for DynamoDB"
  type        = bool
  default     = false
}

variable "enable_ssm_endpoint" {
  description = "Create interface VPC endpoints for SSM/SSM Messages"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Toggle VPC flow logs streaming to CloudWatch Logs"
  type        = bool
  default     = false
}

variable "flow_logs_log_group_name" {
  description = "Optional name for the VPC flow logs CloudWatch log group"
  type        = string
  default     = ""
}

variable "flow_logs_retention_in_days" {
  description = "Retention period for VPC flow logs"
  type        = number
  default     = 90
}

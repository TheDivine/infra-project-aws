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

variable "enable_s3_endpoint" {
  description = "Enable the S3 gateway endpoint"
  type        = bool
  default     = true
}

variable "enable_dynamodb_endpoint" {
  description = "Enable the DynamoDB gateway endpoint"
  type        = bool
  default     = true
}

variable "enable_ssm_endpoint" {
  description = "Enable SSM interface endpoints"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_in_days" {
  description = "Retention period for VPC flow logs"
  type        = number
  default     = 30
}

variable "domain_name" {
  description = "Root domain managed in Route53"
  type        = string
}

variable "additional_domain_names" {
  description = "Subject alternative names for the ACM certificate"
  type        = list(string)
  default     = []
}

variable "app_subdomain" {
  description = "Subdomain for the application ALB record"
  type        = string
  default     = "app"
}

variable "app_container_image" {
  description = "Container image for the ECS service"
  type        = string
}

variable "app_container_port" {
  description = "Container port exposed through the ALB"
  type        = number
  default     = 80
}

variable "app_desired_count" {
  description = "Desired ECS service count"
  type        = number
  default     = 2
}

variable "app_cpu" {
  description = "ECS task CPU units"
  type        = string
  default     = "512"
}

variable "app_memory" {
  description = "ECS task memory in MiB"
  type        = string
  default     = "1024"
}

variable "app_health_check_path" {
  description = "ALB health check path"
  type        = string
  default     = "/"
}

variable "app_assign_public_ip" {
  description = "Assign public IPs to ECS tasks"
  type        = bool
  default     = false
}

variable "app_environment" {
  description = "Environment variables injected into the container"
  type        = map(string)
  default     = {}
}

variable "db_identifier" {
  description = "Identifier for the RDS instance"
  type        = string
  default     = "app-db-dev"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Database admin username"
  type        = string
}

variable "db_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "DB instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Storage allocated to the DB"
  type        = number
  default     = 20
}

variable "redis_name" {
  description = "Redis replication group name"
  type        = string
  default     = "app-cache-dev"
}

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_num_cache_clusters" {
  description = "Number of Redis cache nodes"
  type        = number
  default     = 1
}

variable "redis_auth_token" {
  description = "Optional Redis AUTH token"
  type        = string
  default     = ""
  sensitive   = true
}

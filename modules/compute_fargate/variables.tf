variable "name" {
  description = "Base name for ECS resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the service runs"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the load balancer"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
}

variable "container_port" {
  description = "Container port exposed through the ALB"
  type        = number
  default     = 80
}

variable "desired_count" {
  description = "Desired ECS service count"
  type        = number
  default     = 1
}

variable "cpu" {
  description = "Task CPU (in CPU units)"
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Task memory (in MiB)"
  type        = string
  default     = "512"
}

variable "assign_public_ip" {
  description = "Assign public IPs to the ECS tasks"
  type        = bool
  default     = false
}

variable "container_environment" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "health_check_path" {
  description = "Path used for ALB health checks"
  type        = string
  default     = "/"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listeners"
  type        = string
  default     = ""
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-2016-08"
}

variable "enable_execute_command" {
  description = "Enable ECS exec for the service"
  type        = bool
  default     = true
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention for ECS tasks"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags applied to every resource"
  type        = map(string)
  default     = {}
}

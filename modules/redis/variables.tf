variable "name" {
  description = "Replication group identifier"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for cache nodes"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect"
  type        = list(string)
  default     = []
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "node_type" {
  description = "Cache node instance type"
  type        = string
  default     = "cache.t3.micro"
}

variable "num_cache_clusters" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

variable "port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "auth_token" {
  description = "AUTH token for Redis"
  type        = string
  default     = ""
  sensitive   = true
}

variable "parameter_group_name" {
  description = "Custom parameter group name"
  type        = string
  default     = null
}

variable "maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "sun:03:00-sun:04:00"
}

variable "apply_immediately" {
  description = "Apply modifications immediately"
  type        = bool
  default     = true
}

variable "at_rest_encryption_enabled" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Enable in-transit encryption"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to resources"
  type        = map(string)
  default     = {}
}

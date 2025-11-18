variable "domain_name" {
  description = "Root domain managed in Route53"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional SANs for the ACM certificate"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

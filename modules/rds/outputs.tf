output "endpoint" {
  description = "RDS endpoint address"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDS endpoint port"
  value       = aws_db_instance.this.port
}

output "security_group_id" {
  description = "Security group protecting the instance"
  value       = aws_security_group.this.id
}

output "resource_id" {
  description = "ARN of the DB instance"
  value       = aws_db_instance.this.arn
}

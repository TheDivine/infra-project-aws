output "alb_dns_name" {
  description = "DNS name for the load balancer"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID for the load balancer"
  value       = aws_lb.this.zone_id
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.this.name
}

output "cluster_id" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.this.arn
}

output "target_group_arn" {
  description = "ARN of the ALB target group"
  value       = aws_lb_target_group.this.arn
}

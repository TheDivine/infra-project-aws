output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.primary.zone_id
}

output "zone_name" {
  description = "Route53 hosted zone name"
  value       = aws_route53_zone.primary.name
}

output "certificate_arn" {
  description = "Validated ACM certificate ARN"
  value       = aws_acm_certificate_validation.primary.certificate_arn
}

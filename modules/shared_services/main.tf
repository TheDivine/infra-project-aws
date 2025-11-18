terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
  }
}

resource "aws_route53_zone" "primary" {
  name = var.domain_name
  tags = merge(var.tags, {
    Name = var.domain_name
  })
}

resource "aws_acm_certificate" "primary" {
  domain_name               = var.domain_name
  validation_method         = "DNS"
  subject_alternative_names = var.subject_alternative_names
  lifecycle {
    create_before_destroy = true
  }
  tags = merge(var.tags, {
    Name = "${var.domain_name}-cert"
  })
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.primary.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  name    = each.value.name
  records = [each.value.record]
  ttl     = 60
  type    = each.value.type
  zone_id = aws_route53_zone.primary.zone_id
}

resource "aws_acm_certificate_validation" "primary" {
  certificate_arn         = aws_acm_certificate.primary.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

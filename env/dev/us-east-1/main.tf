provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

locals {
  default_tags = {
    Environment = "dev"
  }

  owner_tags = {
    Owner = "SRE"
  }
}

module "network" {
  source                      = "../../../modules/network"
  vpc_cidr                    = var.vpc_cidr
  public_subnet_cidrs         = var.public_subnet_cidrs
  private_subnet_cidrs        = var.private_subnet_cidrs
  enable_s3_endpoint          = var.enable_s3_endpoint
  enable_dynamodb_endpoint    = var.enable_dynamodb_endpoint
  enable_ssm_endpoint         = var.enable_ssm_endpoint
  enable_flow_logs            = var.enable_flow_logs
  flow_logs_retention_in_days = var.flow_logs_retention_in_days
  tags                        = merge(local.default_tags, local.owner_tags)
}

module "shared_services" {
  source                    = "../../../modules/shared_services"
  domain_name               = var.domain_name
  subject_alternative_names = var.additional_domain_names
  tags                      = merge(local.default_tags, local.owner_tags)
}

module "app" {
  source                = "../../../modules/compute_fargate"
  name                  = "dev-app"
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  container_image       = var.app_container_image
  container_port        = var.app_container_port
  desired_count         = var.app_desired_count
  cpu                   = var.app_cpu
  memory                = var.app_memory
  health_check_path     = var.app_health_check_path
  assign_public_ip      = var.app_assign_public_ip
  container_environment = var.app_environment
  certificate_arn       = module.shared_services.certificate_arn
  tags                  = merge(local.default_tags, local.owner_tags)
}

module "database" {
  source            = "../../../modules/rds"
  identifier        = var.db_identifier
  engine            = "postgres"
  engine_version    = "16.1"
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  db_name           = var.db_name
  username          = var.db_username
  password          = var.db_password
  subnet_ids        = module.network.private_subnet_ids
  vpc_id            = module.network.vpc_id
  vpc_cidr_block    = module.network.vpc_cidr_block
  tags              = merge(local.default_tags, local.owner_tags)
}

module "cache" {
  source             = "../../../modules/redis"
  name               = var.redis_name
  subnet_ids         = module.network.private_subnet_ids
  vpc_id             = module.network.vpc_id
  vpc_cidr_block     = module.network.vpc_cidr_block
  engine_version     = var.redis_engine_version
  node_type          = var.redis_node_type
  num_cache_clusters = var.redis_num_cache_clusters
  auth_token         = var.redis_auth_token
  tags               = merge(local.default_tags, local.owner_tags)
}

resource "aws_route53_record" "app" {
  zone_id = module.shared_services.hosted_zone_id
  name    = "${var.app_subdomain}.${module.shared_services.zone_name}"
  type    = "A"

  alias {
    name                   = module.app.alb_dns_name
    zone_id                = module.app.alb_zone_id
    evaluate_target_health = true
  }
}

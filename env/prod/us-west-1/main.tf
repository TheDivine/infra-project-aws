provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

locals {
  default_tags = {
    Environment = "prod"
  }

  owner_tags = {
    Owner = "SRE"
  }
}

module "network" {
  source               = "../../../modules/network"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = merge(local.default_tags, local.owner_tags)
}

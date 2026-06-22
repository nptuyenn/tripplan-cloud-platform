locals {
  common_tags = {
    Project   = var.project_name
    Env       = var.environment
    Owner     = var.owner
    ManagedBy = "Terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  project_name             = var.project_name
  environment              = var.environment
  vpc_cidr                 = var.vpc_cidr
  azs                      = var.azs
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_subnet_cidrs     = var.private_subnet_cidrs
  data_subnet_cidrs        = var.data_subnet_cidrs
  enable_nat_gateway       = var.enable_nat_gateway
  single_nat_gateway       = var.single_nat_gateway
  flow_logs_retention_days = var.flow_logs_retention_days
  tags                     = local.common_tags
}

module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  route_table_ids    = concat(module.vpc.private_route_table_ids, module.vpc.data_route_table_ids)
  tags               = local.common_tags
}

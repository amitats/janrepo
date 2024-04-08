module "databricks_vpc" {
  source               = "../vpc"
  vpc_block            = var.vpc_block
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  secondary_cidrs      = var.secondary_cidrs
  aws_region           = var.aws_region
  env                  = var.env
  team                 = var.team
}

output "vpc_id" {
  value = module.databricks_vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.databricks_vpc.private_subnet_ids
}

resource "databricks_mws_credentials" "this" {
  provider         = databricks.mws
  account_id       = var.databricks_account_id
  role_arn         = aws_iam_role.cross_account_role.arn
  credentials_name = "${var.team}-${var.product}-${var.env}-creds-${var.aws_region}"
  depends_on       = [time_sleep.wait]
}

resource "databricks_mws_networks" "network" {
  provider           = databricks.mws
  account_id         = var.databricks_account_id
  network_name       = "${var.team}-${var.product}-${var.env}-network-1-${var.aws_region}"
  security_group_ids = [module.databricks_vpc.security_group_id]
  subnet_ids         = module.databricks_vpc.private_subnet_ids
  vpc_id             = module.databricks_vpc.vpc_id
  
  depends_on = [ module.databricks_vpc.aws_route_table_association ]
}

resource "databricks_mws_storage_configurations" "this" {
  provider                   = databricks.mws
  account_id                 = var.databricks_account_id
  bucket_name                = aws_s3_bucket.root_storage_bucket.bucket
  storage_configuration_name = "${var.team}-${var.product}-${var.env}-storage-${var.aws_region}"
}

// Add a 20-second timer to avoid a failed credential validation check.
resource "time_sleep" "wait" {
  depends_on = [
    aws_iam_role.cross_account_role, aws_iam_role_policy.this
  ]
  create_duration = "20s"
}
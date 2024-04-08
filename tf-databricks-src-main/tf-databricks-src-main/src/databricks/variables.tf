variable "aws_region" {
  type = string
}

variable "resident" {
  type = string
}

variable "default_tags" {
  default = {}
}

variable "databricks_account_username" {
  type = string
}

variable "databricks_account_password" {
  type = string
}

variable "databricks_account_id" {
  type = string
}

variable "env" {
  type = string
}

variable "team" {
  type = string
}

variable "name" {
  type = string
}

variable "product" {
  type    = string
  default = "databricks"
}

variable "vpc_block" {
  type        = string
  description = "The VPC CIDR range"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of public subnet CIDRs"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of private subnet CIDRs"
}

variable "secondary_cidrs" {
  type        = list(string)
  description = "List of public CIDRs"
  default     = []
}

variable "cluster_autotermination_minutes" {
  type    = number
  default = 20
}

variable "cluster_data_security_mode" {
  type    = string
  default = "USER_ISOLATION"
}

variable "min_workers" {
  type    = number
  default = 1
}

variable "max_workers" {
  type = number
}

variable "spark_version" {
  type    = string
  default = "13.3.x-scala2.12"
}

variable "runtime_engine" {
  type    = string
  default = "PHOTON"
}

variable "node_type_id" {
  type = string
}

variable "driver_node_type_id" {
  type = string
}

variable "pool_min_idle_instances" {
  type    = number
  default = 0
}

variable "pool_max_capacity" {
  type = number
}

variable "metastore_id" {
  type = string
}

variable "databricks_service_group" {
  default = "None"
  type    = string
}

variable "workspace_admins" {
  type    = list(string)
  default = ["Diwas.Dahal@nbcuni.com", "justin.lu@nbcuni.com"]
}

variable "workspace_users" {
  type    = list(string)
  default = ["mouni.atluri@nbcuni.com", "poorna.nadella@nbcuni.com"]
}

variable "catalog_location_user_group_privileges" {
  type    = list(string)
  default = ["CREATE_TABLE", "READ_FILES", "WRITE_FILES"]
}

variable "catalog_user_group_privileges" {
  type    = list(string)
  default = ["USAGE", "CREATE"]
}

variable "schema_user_group_privileges" {
  type    = list(string)
  default = ["USE_SCHEMA", "CREATE_TABLE"]
}

variable "user_entitlement_settings" {
  type = object({
    allow_cluster_create       = bool
    allow_instance_pool_create = bool
    databricks_sql_access      = bool
    workspace_access           = bool
  })
}

variable "gcp_bigviva_key" {
  type        = string
  description = "gcp_bigviva_key"
  sensitive   = true
}

variable "gcp_pubsub_key" {
  type        = string
  description = "gcp_pubsub_key"
  sensitive   = true
}

variable "remote_state_bucket" {
  type        = string
  description = "Terraform Remote State Bucket Name"
}

variable "remote_state_key" {
  type        = string
  description = "Terraform Remote State Key Name"
}

variable "remote_state_region" {
  type        = string
  description = "Terraform Remote State Region Name"
}

variable "remote_state_bucket_publish" {
  type        = string
  description = "Terraform Remote State Bucket Name"
}

variable "remote_state_key_publish" {
  type        = string
  description = "Terraform Remote State Key Name"
}

variable "remote_state_region_publish" {
  type        = string
  description = "Terraform Remote State Region Name"
}

variable "confluent_consume_key" {
  type    = string
  default = null
}

variable "confluent_publish_key" {
  type    = string
  default = null
}

variable "maxmind_iam_role_arn" {
  type        = string
  description = "IAM Role ARN of Maxmind GeoIP app in Ocellus"
  default     = ""
}

variable "startup_files_iam_role_arn" {
  type        = string
  description = "IAM Role ARN of startup files in Ocellus"
  default     = ""
}

variable "s3_logging_expiration_days" {
  type    = number
  default = 30
}
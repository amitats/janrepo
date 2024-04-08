terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.35.0"
      configuration_aliases = [ databricks.mws, databricks.workspace ]
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.71.0"
    }
  }
  required_version = ">= v1.1.9"
}

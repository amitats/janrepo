data "databricks_spark_version" "latest_lts" {
  provider          = databricks.workspace
  long_term_support = true
  depends_on = [
    databricks_mws_workspaces.this
  ]
}

resource "databricks_cluster" "this" {
  provider       = databricks.workspace
  cluster_name   = "${var.team}-${var.env}-cluster-${var.aws_region}"
  spark_version  = var.spark_version
  runtime_engine = var.runtime_engine

  instance_pool_id = databricks_instance_pool.worker_nodes.id
  autoscale {
    min_workers = var.min_workers
    max_workers = var.max_workers
  }

  autotermination_minutes      = var.cluster_autotermination_minutes
  enable_elastic_disk          = true
  enable_local_disk_encryption = true

  aws_attributes {
    instance_profile_arn   = databricks_instance_profile.shared.id
    availability           = "SPOT"
    first_on_demand        = 3
    zone_id                = "auto"
    spot_bid_price_percent = 100
  }
  data_security_mode = var.cluster_data_security_mode

  depends_on = [
    databricks_mws_workspaces.this, databricks_instance_pool.worker_nodes
  ]
}

output "cluster_url" {
  value = databricks_cluster.this.url
}

resource "databricks_permissions" "cluster_usage" {
  provider   = databricks.workspace
  cluster_id = databricks_cluster.this.id

  access_control {
    group_name       = databricks_group.service_group.display_name
    permission_level = "CAN_ATTACH_TO"
  }

  access_control {
    group_name       = databricks_group.user_group.display_name
    permission_level = "CAN_RESTART"
  }

  access_control {
    group_name       = databricks_group.admin_group.display_name
    permission_level = "CAN_MANAGE"
  }
  depends_on = [
    databricks_mws_workspaces.this
  ]
}


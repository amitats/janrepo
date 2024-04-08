resource "databricks_instance_pool" "worker_nodes" {
  provider           = databricks.workspace
  instance_pool_name = upper("${var.team} ${var.env} INSTANCE POOL ${var.aws_region}")
  min_idle_instances = var.pool_min_idle_instances
  max_capacity       = var.pool_max_capacity
  node_type_id       = var.node_type_id
  preloaded_spark_versions = [
    data.databricks_spark_version.latest_lts.id
  ]
  idle_instance_autotermination_minutes = var.cluster_autotermination_minutes

  depends_on = [
    databricks_mws_workspaces.this
    ]
}

resource "databricks_permissions" "pool_usage" {
  provider         = databricks.workspace
  instance_pool_id = databricks_instance_pool.worker_nodes.id

  access_control {
    group_name       = databricks_group.user_group.display_name
    permission_level = "CAN_ATTACH_TO"
  }

  access_control {
    group_name       = databricks_group.service_group.display_name
    permission_level = "CAN_ATTACH_TO"
  }

  access_control {
    group_name       = databricks_group.admin_group.display_name
    permission_level = "CAN_MANAGE"
  }

  depends_on = [
    databricks_mws_workspaces.this,
    databricks_instance_pool.worker_nodes,
    databricks_group.admin_group,
    databricks_group.user_group,
    databricks_group.service_group
  ]
}
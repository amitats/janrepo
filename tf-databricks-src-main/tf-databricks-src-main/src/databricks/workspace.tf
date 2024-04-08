resource "databricks_mws_workspaces" "this" {
  provider   = databricks.mws
  account_id = var.databricks_account_id

  aws_region     = var.aws_region
  workspace_name = upper("${var.env} ${var.aws_region} ${var.team} WORKSPACE")

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.network.network_id
  deployment_name          = "${var.name}-${var.env}-${var.aws_region}"

  depends_on                 = [databricks_mws_networks.network]
}

// Capture the Databricks workspace's URL.
output "databricks_host" {
  value = databricks_mws_workspaces.this.workspace_url
}

resource "databricks_metastore_assignment" "workspace_assignment" {
  provider             = databricks.workspace
  workspace_id         = split("/", databricks_mws_workspaces.this.id)[1]
  metastore_id         = var.metastore_id
  default_catalog_name = "workspace_catalog"
  depends_on           = [databricks_mws_workspaces.this]
}

# Service Accounts
resource "databricks_service_principal" "service_accounts" {
  provider             = databricks.mws
  display_name         = "${var.env}-${var.aws_region}-service"
  allow_cluster_create = true
}

resource "databricks_mws_permission_assignment" "add_admin_sp" {
  provider             = databricks.mws
  workspace_id         = databricks_mws_workspaces.this.workspace_id
  principal_id         = databricks_service_principal.service_accounts.id
  permissions          = ["ADMIN"]
}

resource "databricks_service_principal_secret" "service_account_key" {
  provider             = databricks.mws
  service_principal_id = databricks_service_principal.service_accounts.id
}

output "oauth_id" {
  value = databricks_service_principal_secret.service_account_key.id
}

output "oauth_secret" {
  value = databricks_service_principal_secret.service_account_key.secret
}

resource "databricks_token" "pat" {
  provider = databricks.workspace
}

output "workspace_pat" {
  value     = databricks_token.pat.token_value
  sensitive = true
}

resource "databricks_group" "service_group" {
  provider     = databricks.mws
  display_name = "${var.env}-${var.aws_region}-service-group"
}

resource "databricks_group_member" "service_group_member" {
  provider   = databricks.mws
  group_id   = databricks_group.service_group.id
  member_id  = databricks_service_principal.service_accounts.id
  depends_on = [databricks_group.service_group, databricks_service_principal.service_accounts]
}

resource "databricks_mws_permission_assignment" "add_service_group" {
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = databricks_group.service_group.id
  permissions  = ["USER"]
  depends_on   = [databricks_group.service_group]
}

# Workspace User Groups
resource "databricks_group" "admin_group" {
  provider     = databricks.mws
  display_name = "${var.env}-${var.aws_region}-workspace-admins"
}

resource "databricks_mws_permission_assignment" "add_admin_group" {
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = databricks_group.admin_group.id
  permissions  = ["ADMIN"]
  depends_on   = [databricks_group.admin_group]
}

resource "databricks_group" "user_group" {
  provider     = databricks.mws
  display_name = "${var.env}-${var.aws_region}-workspace-users"
}

resource "databricks_mws_permission_assignment" "add_user_group" {
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = databricks_group.user_group.id
  permissions  = ["USER"]
  depends_on   = [databricks_group.user_group]
}

resource "databricks_entitlements" "workspace-users" {
  provider                   = databricks.workspace
  group_id                   = databricks_group.user_group.id
  allow_cluster_create       = var.user_entitlement_settings.allow_cluster_create
  allow_instance_pool_create = var.user_entitlement_settings.allow_instance_pool_create
  databricks_sql_access      = var.user_entitlement_settings.databricks_sql_access
  workspace_access           = var.user_entitlement_settings.workspace_access
  depends_on                 = [databricks_group.user_group]
}

resource "databricks_entitlements" "workspace-admins" {
  provider                   = databricks.workspace
  group_id                   = databricks_group.admin_group.id
  allow_cluster_create       = true
  allow_instance_pool_create = true
  databricks_sql_access      = true
  workspace_access           = true
  depends_on                 = [databricks_group.admin_group]
}

resource "databricks_entitlements" "workspace-service" {
  provider                   = databricks.workspace
  group_id                   = databricks_group.service_group.id
  allow_cluster_create       = true
  allow_instance_pool_create = true
  databricks_sql_access      = true
  workspace_access           = true
  depends_on                 = [databricks_group.service_group]
}

resource "null_resource" "update_group_members" {
  # triggers = {
  #   workspace_admins = jsonencode(var.workspace_admins)
  #   workspace_users  = jsonencode(var.workspace_users)
  # }
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "${path.module}/workspace_users.sh"
    environment = {
      DATABRICKS_ACCOUNT_ID = var.databricks_account_id
      DATABRICKS_USERNAME   = var.databricks_account_username
      DATABRICKS_PASSWORD   = var.databricks_account_password
      DATABRICKS_ENV        = var.env
      DATABRICKS_REGION     = var.aws_region
      WORKSPACE_ID          = databricks_group.user_group.id
      WORKSPACE_ADMINS      = jsonencode(var.workspace_admins)
      WORKSPACE_USERS       = jsonencode(var.workspace_users)
    }
  }
  depends_on = [
    databricks_mws_workspaces.this,
    databricks_schema.default,
    databricks_group.admin_group,
    databricks_group.user_group,
    databricks_group.service_group
  ]
}

resource "databricks_global_init_script" "init_script" {
  provider = databricks.workspace
  source   = "${path.module}/global_init.sh"
  name     = "Global Init Script for the Databricks workspace"
  enabled  = true
}

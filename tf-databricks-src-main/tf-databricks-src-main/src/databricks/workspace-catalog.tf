locals {
  prefix = "${var.team}-${var.product}-${var.env}-${var.aws_region}"
}

resource "aws_s3_bucket" "catalog_bucket" {
  bucket        = "${local.prefix}-catalog-bucket"
  force_destroy = true
  tags = merge(var.default_tags, {
    Name = "${local.prefix}-catalog-bucket"
  })
}

resource "aws_s3_bucket_ownership_controls" "catalog_bucket_control" {
  bucket = aws_s3_bucket.catalog_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "catalog_versioning" {
  bucket = aws_s3_bucket.catalog_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "catalog_bucket_public_access_block" {
  bucket             = aws_s3_bucket.catalog_bucket.id
  ignore_public_acls = true
  depends_on         = [aws_s3_bucket.catalog_bucket]
}

data "databricks_aws_bucket_policy" "databricks_policy" {
  bucket = aws_s3_bucket.catalog_bucket.bucket
}

data "aws_iam_policy_document" "allow_access_from_ocellus" {
  statement {
    sid = "OcellusMaxmindAccess"
    principals {
      type        = "AWS"
      identifiers = [var.maxmind_iam_role_arn]
    }
    actions = [
      "s3:DeleteObject",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.catalog_bucket.arn,
      "${aws_s3_bucket.catalog_bucket.arn}/*",
    ]
  }
}

data "aws_iam_policy_document" "allow_access_from_ocellus_startup_files" {
  statement {
    sid = "OcellusStartupFilesAccess"
    principals {
      type        = "AWS"
      identifiers = [var.startup_files_iam_role_arn]
    }
    actions = [
      "s3:DeleteObject",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.catalog_bucket.arn,
      "${aws_s3_bucket.catalog_bucket.arn}/*",
    ]
  }
}


data "aws_iam_policy_document" "catalog_bucket_data" {
  source_policy_documents = concat(
    [
      data.databricks_aws_bucket_policy.databricks_policy.json
    ],
    var.maxmind_iam_role_arn != "" ? [
      data.aws_iam_policy_document.allow_access_from_ocellus.json
    ] : [],
    var.startup_files_iam_role_arn != "" ? [
      data.aws_iam_policy_document.allow_access_from_ocellus_startup_files.json
    ] : [],
  )
}

resource "aws_s3_bucket_policy" "catalog_bucket_policy" {
  bucket     = aws_s3_bucket.catalog_bucket.id
  policy     = data.aws_iam_policy_document.catalog_bucket_data.json
  depends_on = [aws_s3_bucket_public_access_block.catalog_bucket_public_access_block]
}

data "aws_iam_policy_document" "passrole_for_uc" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL",
                     "arn:aws:iam::${var.resident}:role/${local.prefix}-external-access"]
      type        = "AWS"
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.databricks_account_id]
    }
  }
}

resource "aws_iam_policy" "external_data_access" {
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${local.prefix}-catalog"
    Statement = [
      {
        "Action" : [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        "Resource" : [
          aws_s3_bucket.catalog_bucket.arn,
          "${aws_s3_bucket.catalog_bucket.arn}/*"
        ],
        "Effect" : "Allow"
      }
    ]
  })
  tags = merge(var.default_tags, {
    Name = "${local.prefix}-unity-catalog IAM policy"
  })
}

resource "aws_iam_role" "external_data_access" {
  name                 = "${local.prefix}-external-access"
  assume_role_policy   = data.aws_iam_policy_document.passrole_for_uc.json
  permissions_boundary = "arn:aws:iam::${var.resident}:policy/org/nbcuaux-policy-residentPermissionsBoundary"
  managed_policy_arns  = [aws_iam_policy.external_data_access.arn]
  tags = merge(var.default_tags, {
    Name = "${local.prefix}-unity-catalog external access IAM role"
  })
  depends_on = [aws_iam_policy.external_data_access]
}

resource "databricks_storage_credential" "external" {
  provider = databricks.workspace
  name     = aws_iam_role.external_data_access.name
  aws_iam_role {
    role_arn = aws_iam_role.external_data_access.arn
  }
  comment    = "Managed by TF"
  depends_on = [databricks_metastore_assignment.workspace_assignment, aws_iam_role.external_data_access]
}

resource "databricks_external_location" "catalog_location" {
  provider        = databricks.workspace
  name            = "${var.env}-${var.aws_region}-external-location"
  url             = "s3://${aws_s3_bucket.catalog_bucket.bucket}"
  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
  depends_on      = [aws_s3_bucket.catalog_bucket, databricks_storage_credential.external]
  force_destroy   = true
}

resource "databricks_catalog" "this" {
  provider     = databricks.workspace
  metastore_id = var.metastore_id
  storage_root = "s3://${aws_s3_bucket.catalog_bucket.bucket}"
  name         = "${var.env}-${var.aws_region}-default-catalog"
  comment      = "This catalog is managed by terraform"
  properties = {
    purpose = "Default workspace catalog"
  }
  depends_on = [databricks_external_location.catalog_location, databricks_metastore_assignment.workspace_assignment]

  force_destroy = true
}

resource "databricks_schema" "default" {
  provider     = databricks.workspace
  catalog_name = databricks_catalog.this.id
  name         = "${var.env}-${var.aws_region}-default-schema"
  comment      = "This schema is managed by terraform"
  properties = {
    kind = "various"
  }
  force_destroy = true
  depends_on    = [databricks_catalog.this]
}

resource "databricks_grants" "catalog_location" {
  provider          = databricks.workspace
  external_location = databricks_external_location.catalog_location.id
  grant {
    principal  = databricks_group.service_group.display_name
    privileges = ["CREATE_EXTERNAL_TABLE", "READ_FILES"]
  }
  grant {
    principal  = databricks_group.admin_group.display_name
    privileges = ["CREATE_EXTERNAL_TABLE", "READ_FILES", "WRITE_FILES"]
  }
  grant {
    principal  = databricks_group.user_group.display_name
    privileges = var.catalog_location_user_group_privileges
  }
  depends_on = [
    databricks_external_location.catalog_location,
    databricks_group.admin_group,
    databricks_group.user_group,
    databricks_group.service_group
  ]
}

resource "databricks_grants" "catalog_grant" {
  provider = databricks.workspace
  catalog  = databricks_catalog.this.name
  grant {
    principal  = databricks_group.service_group.display_name
    privileges = ["USE_CATALOG", "USE_SCHEMA", "CREATE_TABLE"]
  }
  grant {
    principal  = databricks_group.admin_group.display_name
    privileges = ["USE_CATALOG", "CREATE_SCHEMA"]
  }
  grant {
    principal  = databricks_group.user_group.display_name
    privileges = var.catalog_user_group_privileges
  }
  depends_on = [
    databricks_catalog.this,
    databricks_group.admin_group,
    databricks_group.user_group,
    databricks_group.service_group
  ]
}

resource "databricks_grants" "schema_grant" {
  provider = databricks.workspace
  schema   = databricks_schema.default.id
  grant {
    principal  = databricks_group.service_group.display_name
    privileges = ["CREATE_FUNCTION", "CREATE_TABLE", "USE_SCHEMA"]
  }
  grant {
    principal  = databricks_group.admin_group.display_name
    privileges = ["CREATE_FUNCTION", "CREATE_TABLE", "USE_SCHEMA"]
  }
  grant {
    principal  = databricks_group.user_group.display_name
    privileges = var.schema_user_group_privileges
  }
  depends_on = [
    databricks_schema.default,
    databricks_group.admin_group,
    databricks_group.user_group,
    databricks_group.service_group
  ]
}

resource "databricks_mount" "s3_mount" {
  provider = databricks.workspace
  name     = "s3-mount"
  s3 {
    instance_profile = databricks_instance_profile.shared.id
    bucket_name      = aws_s3_bucket.catalog_bucket.bucket
  }
  depends_on = [
    aws_s3_bucket_policy.catalog_bucket_policy,
    databricks_mws_workspaces.this
  ]
}

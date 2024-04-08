resource "aws_s3_bucket" "logging_bucket" {
  bucket        = "${local.prefix}-logging"
  force_destroy = true
  tags = merge(var.default_tags, {
    Name = "${local.prefix}-logging"
  })
}

resource "aws_s3_bucket_ownership_controls" "logging_bucket_control" {
  bucket = aws_s3_bucket.logging_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logging_bucket_acl" {
  bucket = aws_s3_bucket.logging_bucket.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.logging_bucket_control]
}

resource "aws_s3_bucket_lifecycle_configuration" "logging_bucket_lifecycle" {
  bucket = aws_s3_bucket.logging_bucket.id
  rule {
    id      = "DeleteAfter14Days"
    status  = "Enabled"
    expiration {
      days  = var.s3_logging_expiration_days
    }
  }
}

resource "aws_s3_bucket_versioning" "logging_versioning" {
  bucket = aws_s3_bucket.logging_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "logging_bucket_public_access_block" {
  bucket             = aws_s3_bucket.logging_bucket.id
  ignore_public_acls = true
  depends_on         = [aws_s3_bucket.logging_bucket]
}

data "databricks_aws_bucket_policy" "databricks_logging_policy" {
  bucket = aws_s3_bucket.logging_bucket.bucket
}

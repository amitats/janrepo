## workspace root storage
resource "aws_s3_bucket" "root_storage_bucket" {
  bucket        = "${var.team}-${var.product}-${var.env}-rootbucket-${var.aws_region}"
  force_destroy = true
  tags = merge(var.default_tags, {
    Name = "${var.team}-${var.product}-${var.env}-rootbucket-${var.aws_region}"
  })
}

resource "aws_s3_bucket_ownership_controls" "root_storage_bucket_control" {
  bucket = aws_s3_bucket.root_storage_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "root_storage_bucket_acl" {
  bucket = aws_s3_bucket.root_storage_bucket.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.root_storage_bucket_control]
}
resource "aws_s3_bucket_versioning" "root_versioning" {
  bucket = aws_s3_bucket.root_storage_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "root_storage_bucket" {
  bucket             = aws_s3_bucket.root_storage_bucket.id
  ignore_public_acls = true
  depends_on         = [aws_s3_bucket.root_storage_bucket]
}


data "databricks_aws_bucket_policy" "root_storage_bucket" {
  bucket = aws_s3_bucket.root_storage_bucket.bucket
}

resource "aws_s3_bucket_policy" "root_bucket_policy" {
  bucket     = aws_s3_bucket.root_storage_bucket.id
  policy     = data.databricks_aws_bucket_policy.root_storage_bucket.json
  depends_on = [aws_s3_bucket_public_access_block.root_storage_bucket]
}
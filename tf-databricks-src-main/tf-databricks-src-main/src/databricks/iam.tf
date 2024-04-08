locals {
  resident             = var.resident
  permissions_boundary = "arn:aws:iam::${var.resident}:policy/org/nbcuaux-policy-residentPermissionsBoundary"
}

data "databricks_aws_assume_role_policy" "assume_cross_acount_role" {
  external_id = var.databricks_account_id
}

resource "aws_iam_role" "cross_account_role" {
  name                 = "${var.team}-${var.product}-${var.env}-crossaccount-role-${var.aws_region}"
  permissions_boundary = local.permissions_boundary
  assume_role_policy   = data.databricks_aws_assume_role_policy.assume_cross_acount_role.json
  tags                 = var.default_tags
}

data "databricks_aws_crossaccount_policy" "this" {}

resource "aws_iam_role_policy" "this" {
  name   = "${var.team}-${var.product}-${var.env}-crossaccount-policy-${var.aws_region}"
  role   = aws_iam_role.cross_account_role.id
  policy = data.databricks_aws_crossaccount_policy.this.json
}

resource "aws_iam_role_policy" "passrole_policy" {
  name = "${var.team}-${var.product}-${var.env}-passrole-policy-${var.aws_region}"
  role = aws_iam_role.cross_account_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : "iam:PassRole",
        "Resource" : [aws_iam_role.instance_profile_role.arn]
      }
    ]
  })
}

resource "aws_iam_policy" "cross_account_self_assume" {
  name   = "${var.team}-${var.product}-${var.env}-crossaccount-self_assume_policy-${var.aws_region}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": ["sts:AssumeRole"],
            "Effect": "Allow",
            "Resource": ["arn:aws:iam::${var.resident}:role/${var.team}-${var.product}-${var.env}-crossaccount-role-${var.aws_region}"]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "role_attachement_cross_account_self_assume" {
  role       = aws_iam_role.cross_account_role.name
  policy_arn = aws_iam_policy.cross_account_self_assume.arn
}

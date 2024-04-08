resource "aws_secretsmanager_secret" "aws_secrets_manager_bigquery" {
  name = "${var.team}-${var.product}-secret-bigquery"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret" "aws_secrets_manager_pubsub" {
  name = "${var.team}-${var.product}-secret-pubsub"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret" "aws_secrets_manager_kafka_consume" {
  name = "${var.team}-${var.product}-kafka-consume"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret" "aws_secrets_manager_kafka_publish" {
  name = "${var.team}-${var.product}-kafka-publish"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "sversion_bigquery" {
  secret_id     = aws_secretsmanager_secret.aws_secrets_manager_bigquery.id
  secret_string = var.gcp_bigviva_key
}

resource "aws_secretsmanager_secret_version" "sversion_pubsub" {
  secret_id     = aws_secretsmanager_secret.aws_secrets_manager_pubsub.id
  secret_string = var.gcp_pubsub_key
}

data "terraform_remote_state" "ocellus_confluent" {
  backend = "s3"
  config = {
    bucket = var.remote_state_bucket
    key    = var.remote_state_key
    region = var.remote_state_region
  }
}

resource "aws_secretsmanager_secret_version" "sversion_kafka_consume" {
  secret_id = aws_secretsmanager_secret.aws_secrets_manager_kafka_consume.id
  secret_string = jsonencode({
    key_id             = data.terraform_remote_state.ocellus_confluent.outputs.sa_confluent_account_creds.api_keys[var.confluent_consume_key].id
    key_secret         = data.terraform_remote_state.ocellus_confluent.outputs.sa_confluent_account_creds.api_keys[var.confluent_consume_key].secret
    bootstrap_endpoint = data.terraform_remote_state.ocellus_confluent.outputs.confluent_kafka_cluster_dedicated_bootstrap_endpoint
  })
}

data "terraform_remote_state" "ocellus_confluent_publish" {
  backend = "s3"
  config = {
    bucket = var.remote_state_bucket_publish
    key    = var.remote_state_key_publish
    region = var.remote_state_region_publish
  }
}

resource "aws_secretsmanager_secret_version" "sversion_kafka_publish" {
  secret_id = aws_secretsmanager_secret.aws_secrets_manager_kafka_publish.id
  secret_string = jsonencode({
    key_id             = data.terraform_remote_state.ocellus_confluent_publish.outputs.sa_confluent_account_creds.api_keys[var.confluent_publish_key].id
    key_secret         = data.terraform_remote_state.ocellus_confluent_publish.outputs.sa_confluent_account_creds.api_keys[var.confluent_publish_key].secret
    bootstrap_endpoint = data.terraform_remote_state.ocellus_confluent_publish.outputs.confluent_kafka_cluster_dedicated_bootstrap_endpoint
  })
}

resource "aws_iam_policy" "secretsmanger_keys_policy" {
  name   = "${var.team}-${var.product}-${var.env}-secretsmanager-keys-policy-${var.aws_region}"
  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": "secretsmanager:GetSecretValue",
			"Resource": [
                "${aws_secretsmanager_secret.aws_secrets_manager_bigquery.arn}",
                "${aws_secretsmanager_secret.aws_secrets_manager_pubsub.arn}",
                "${aws_secretsmanager_secret.aws_secrets_manager_kafka_consume.arn}",
                "${aws_secretsmanager_secret.aws_secrets_manager_kafka_publish.arn}"
                ]
		}
	]
}
EOF
}

resource "aws_iam_policy" "s3_bucket_policy" {
  name   = "${var.team}-${var.product}-${var.env}-s3-bucket-policy-${var.aws_region}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": ["${aws_s3_bucket.catalog_bucket.arn}", "${aws_s3_bucket.logging_bucket.arn}", "arn:aws:s3:::ocellus-databricks-received-${var.env}-${var.aws_region}-logging"]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:PutObjectAcl"
            ],
            "Resource": ["${aws_s3_bucket.catalog_bucket.arn}/*", "${aws_s3_bucket.logging_bucket.arn}/*", "arn:aws:s3:::ocellus-databricks-received-${var.env}-${var.aws_region}-logging/*"]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "instance_profile_self_assume" {
  name   = "${var.team}-${var.product}-${var.env}-instance-profile-self-assume-policy-${var.aws_region}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": ["sts:AssumeRole"],
            "Effect": "Allow",
            "Resource": ["arn:aws:iam::${var.resident}:role/${var.team}-${var.product}-${var.env}-instance-profile-role-${var.aws_region}"]
        }
    ]
}
EOF
}

resource "aws_iam_role" "instance_profile_role" {
  name                 = "${var.team}-${var.product}-${var.env}-instance-profile-role-${var.aws_region}"
  permissions_boundary = "arn:aws:iam::${var.resident}:policy/org/nbcuaux-policy-residentPermissionsBoundary"
  assume_role_policy   = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "role_attachment_instance_profile" {                                                                          
  role       = aws_iam_role.instance_profile_role.name                                                                                      
  policy_arn = aws_iam_policy.instance_profile_self_assume.arn                                                                              
}                                                                              

resource "aws_iam_role_policy_attachment" "role_attachment_keys" {
  role       = aws_iam_role.instance_profile_role.name
  policy_arn = aws_iam_policy.secretsmanger_keys_policy.arn
}

resource "aws_iam_role_policy_attachment" "role_attachment_s3" {
  role       = aws_iam_role.instance_profile_role.name
  policy_arn = aws_iam_policy.s3_bucket_policy.arn
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.team}-${var.product}-${var.env}-instance-profile-${var.aws_region}"
  role = aws_iam_role.instance_profile_role.name
}

resource "databricks_instance_profile" "shared" {
  provider             = databricks.workspace
  instance_profile_arn = aws_iam_instance_profile.instance_profile.arn
  iam_role_arn         = aws_iam_role.instance_profile_role.arn
  skip_validation      = true
}

resource "databricks_group_instance_profile" "users" {
  provider            = databricks.workspace
  group_id            = databricks_group.user_group.id
  instance_profile_id = databricks_instance_profile.shared.id
}

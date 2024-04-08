#!/bin/bash

# Download the AWS CLI v2 installer
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Unzip the installer
unzip awscliv2.zip

# Install AWS CLI v2
sudo ./aws/install

# Clean up (optional)
rm -rf awscliv2.zip aws

sudo apt-get install jq
gcp_bigquery_json_data=$(aws secretsmanager get-secret-value --secret-id aws_secrets_manager_databricks_bigquery_keys --query SecretString --output text)
project_id=`echo "$gcp_bigquery_json_data" | jq -r '.project_id'`
private_key=`echo "$gcp_bigquery_json_data" | jq -r '.private_key'`
client_email=`echo "$gcp_bigquery_json_data" | jq -r '.client_email'`
private_key_id=`echo "$gcp_bigquery_json_data" | jq -r '.private_key_id'`
email_id=`echo "$gcp_bigquery_json_data" | jq -r '.client_email'`
private_key_escape_newline=$(echo -n "$private_key" | awk 'NF {sub(/\r/,""); printf "%s\\n", $0}')
spark_defaults_conf="$DB_HOME/driver/conf/spark-defaults.conf"
cat << EOF >>  $spark_defaults_conf
"spark.hadoop.fs.gs.auth.service.account.email" = "$client_email"
"spark.hadoop.fs.gs.auth.service.account.private.key.id" = "$private_key_id"
"spark.hadoop.google.cloud.auth.service.account.enable" = "true"
"spark.hadoop.fs.gs.project.id" = "$project_id"
"spark.hadoop.fs.gs.auth.service.account.private.key" = "$private_key_escape_newline"
EOF

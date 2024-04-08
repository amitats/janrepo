#!/bin/bash

DATABRICKS_HOST='https://accounts.cloud.databricks.com'

# Access the workspace_admins and workspace_users variables as environment variables
workspace_admins=($(echo "$WORKSPACE_ADMINS" | jq -r '.[]'))
workspace_users=($(echo "$WORKSPACE_USERS" | jq -r '.[]'))

# Function to create a user if it doesn't exist and return the user ID
create_or_get_user_id() {
  local user_email="$1"
  local user_name="$user_email"  # You can customize the user name as needed

  user_id=$(curl --request GET "${DATABRICKS_HOST}/api/2.0/accounts/${DATABRICKS_ACCOUNT_ID}/scim/v2/Users" \
    --user "${DATABRICKS_USERNAME}:${DATABRICKS_PASSWORD}" |
    jq -r ".Resources[] | select(.userName == \"${user_email}\") | .id")

  if [ -z "$user_id" ]; then
    echo "Creating user ${user_email}"
    user_data=$(jq -n --arg user_email "$user_email" --arg user_name "$user_name" '{
      "schemas": ["urn:ietf:params:scim:schemas:core:2.0:User"],
      "userName": $user_email,
      "name": {
        "familyName": $user_name
      }
    }')

    user_id=$(curl --request POST "${DATABRICKS_HOST}/api/2.0/accounts/${DATABRICKS_ACCOUNT_ID}/scim/v2/Users" \
      --user "${DATABRICKS_USERNAME}:${DATABRICKS_PASSWORD}" \
      --header "Content-Type: application/json" \
      --data "$user_data" |
      jq -r ".id")

    echo "Created user ${user_email} with ID ${user_id}"
  fi

  echo "$user_id"
}

# Function to add a user to a group by group name
add_user_to_group_by_name() {
  local user_id="$1"
  local group_name="$2"

  # Get the group ID using the group name
  group_id=$(curl --request GET "${DATABRICKS_HOST}/api/2.0/accounts/${DATABRICKS_ACCOUNT_ID}/scim/v2/Groups" \
    --user "${DATABRICKS_USERNAME}:${DATABRICKS_PASSWORD}" |
    jq -r ".Resources[] | select(.displayName == \"${group_name}\") | .id")

  if [ -z "$group_id" ]; then
    echo "Group ${group_name} not found or created"
    return
  fi

  response=$(curl --request PATCH "${DATABRICKS_HOST}/api/2.0/accounts/${DATABRICKS_ACCOUNT_ID}/scim/v2/Groups/${group_id}" \
    --user "${DATABRICKS_USERNAME}:${DATABRICKS_PASSWORD}" \
    --header "Content-Type: application/json" \
    --data '{
      "schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
      "Operations": [
        {
          "op": "add",
          "path": "members",
          "value": [
            {
              "value": "'"${user_id}"'"
            }
          ]
        }
      ]
    }')
}

# Create the groups first
group_name_admins="${DATABRICKS_ENV}-${DATABRICKS_REGION}-workspace-admins"
group_name_users="${DATABRICKS_ENV}-${DATABRICKS_REGION}-workspace-users"

# Loop for adding users to groups
for user_email in "${workspace_admins[@]}" "${workspace_users[@]}"; do
  if [ -z "$user_email" ]; then
    continue  # Skip empty user emails
  fi

  group_name="${DATABRICKS_ENV}-${DATABRICKS_REGION}-workspace-admins"
  if [[ "${workspace_users[@]}" =~ "${user_email}" ]]; then
    group_name="${DATABRICKS_ENV}-${DATABRICKS_REGION}-workspace-users"
  fi

  echo "Adding user ${user_email} to group ${group_name}"

  # Get or create the user and retrieve their user ID
  user_id=$(create_or_get_user_id "$user_email")

  if [ -z "$user_id" ]; then
    echo "User ${user_email} not found or created"
    continue
  fi

  # Add the user to the group by group name
  add_user_to_group_by_name "$user_id" "$group_name"
  echo "Added user ${user_email} to group ${group_name}"
done
#!/usr/bin/env bash
set -eu

# Define repository name for reuse
REPO_NAME=""

# Azure/ARM credentials
CLIENT_ID=""
CLIENT_SECRET=""
SUBSCRIPTION_ID=""
TENANT_ID=""
GITHUB_RUNNER_TOKEN=""


# Azure credentials as JSON
AZURE_CREDENTIALS=$(cat <<EOF
{
  "clientId": "${CLIENT_ID}",
  "clientSecret": "${CLIENT_SECRET}",
  "subscriptionId": "${SUBSCRIPTION_ID}",
  "tenantId": "${TENANT_ID}"
}
EOF
)

# Declare an associative array to hold secrets and their corresponding values
declare -A secrets=(
  ["AZURE_CREDENTIALS"]="${AZURE_CREDENTIALS}"
  ["ARM_CLIENT_ID"]="${CLIENT_ID}"
  ["ARM_CLIENT_SECRET"]="${CLIENT_SECRET}"
  ["ARM_SUBSCRIPTION_ID"]="${SUBSCRIPTION_ID}"
  ["ARM_TENANT_ID"]="${TENANT_ID}"
  ["MY_USER_OBJECT_ID"]=""
  ["RUNNER_TOKEN"]="${GITHUB_RUNNER_TOKEN}"
)

# Iterate over the secrets and set them using `gh secret set`
for secret_name in "${!secrets[@]}"; do
  gh secret set "$secret_name" --repo "$REPO_NAME" --body "${secrets[$secret_name]}"
done

echo "All secrets have been set successfully!"

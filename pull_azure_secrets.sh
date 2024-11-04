#!/bin/bash

# Directory where secrets will be saved
SECRETS_DIR="/mnt/secrets"
# Vault path to fetch the credentials, passed as the first argument
CREDS_PATH=${1:-azure/creds/azure-service-principal}

# Check if VAULT_ADDR and VAULT_TOKEN are set
if [ -z "$VAULT_ADDR" ]; then
    echo "Error: VAULT_ADDR is not set. Exiting."
    exit 1
fi

if [ -z "$VAULT_TOKEN" ]; then
    echo "Error: VAULT_TOKEN is not set. Exiting."
    exit 1
fi

# Ensure the directory exists
mkdir -p "$SECRETS_DIR" || {
    echo "Error: Failed to create SECRETS_DIR at $SECRETS_DIR. Exiting."
    exit 1
}

# Pull secrets and save to individual files
vault-sidekick -one-shot \
      -output="${SECRETS_DIR}" \
      -auth="${SECRETS_DIR}/vault-auth.yaml" \
      -vault="$VAULT_ADDR" \
      -cn="secret:${CREDS_PATH}:file=azure-creds,update=1h,fmt=txt" || {
    echo "Error: vault-sidekick failed to pull secrets. Exiting."
    exit 1
}

# Export Azure credentials as environment variables
export AZURE_CLIENT_ID=$(cat "$SECRETS_DIR/azure-creds.client_id" 2>/dev/null)
export AZURE_CLIENT_SECRET=$(cat "$SECRETS_DIR/azure-creds.client_secret" 2>/dev/null)
export AZURE_TENANT_ID=$(cat "$SECRETS_DIR/azure-creds.tenant_id" 2>/dev/null)
export AZURE_SUBSCRIPTION_ID=$(cat "$SECRETS_DIR/azure-creds.subscription_id" 2>/dev/null)

# Verify if the environment variables are set
if [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_CLIENT_SECRET" ] || [ -z "$AZURE_TENANT_ID" ] || [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
    echo "Error: One or more Azure environment variables could not be set. Exiting."
    exit 1
fi

# Final confirmation message
echo "Azure credentials have been successfully set from Vault"

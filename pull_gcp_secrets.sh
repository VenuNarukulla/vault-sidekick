#!/bin/bash

# Directory where secrets will be saved
SECRETS_DIR="/mnt/secrets"
# Vault path to fetch the credentials, passed as the first argument
CREDS_PATH=${1:-gcp/creds/gcp-service-account}

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
      -cn="secret:${CREDS_PATH}:file=gcp-creds,update=1h,fmt=txt" || {
    echo "Error: vault-sidekick failed to pull secrets. Exiting."
    exit 1
}

# Export GCP credentials as environment variables
export GCP_PROJECT_ID=$(cat "$SECRETS_DIR/gcp-creds.project_id" 2>/dev/null)
export GCP_PRIVATE_KEY=$(cat "$SECRETS_DIR/gcp-creds.private_key" 2>/dev/null)
export GCP_CLIENT_EMAIL=$(cat "$SECRETS_DIR/gcp-creds.client_email" 2>/dev/null)
export GCP_TOKEN_URI=$(cat "$SECRETS_DIR/gcp-creds.token_uri" 2>/dev/null)

# Verify if the environment variables are set
if [ -z "$GCP_PROJECT_ID" ] || [ -z "$GCP_PRIVATE_KEY" ] || [ -z "$GCP_CLIENT_EMAIL" ] || [ -z "$GCP_TOKEN_URI" ]; then
    echo "Error: One or more GCP environment variables could not be set. Exiting."
    exit 1
fi

# Final confirmation message
echo "GCP credentials have been successfully set from Vault"

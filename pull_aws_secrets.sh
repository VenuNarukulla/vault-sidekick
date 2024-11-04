#!/bin/bash

# Directory where secrets will be saved
SECRETS_DIR="/mnt/secrets"
# Vault path to fetch the credentials, passed as the first argument
CREDS_PATH=${1:-aws/creds/aws-s3-role}

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

# Write the Vault token to vault-auth.yaml
cat <<EOF > "${SECRETS_DIR}/vault-auth.yaml"
method: token
token: ${VAULT_TOKEN}
EOF

# Pull secrets and save to individual files
vault-sidekick -one-shot \
      -output="${SECRETS_DIR}" \
      -auth="${SECRETS_DIR}/vault-auth.yaml" \
      -vault="$VAULT_ADDR" \
      -cn="secret:${CREDS_PATH}:file=aws-creds,update=1h,fmt=txt" || {
    echo "Error: vault-sidekick failed to pull secrets. Exiting."
    exit 1
}

# Export AWS credentials as environment variables
export AWS_ACCESS_KEY_ID=$(cat "$SECRETS_DIR/aws-creds.access_key" 2>/dev/null)
export AWS_SECRET_ACCESS_KEY=$(cat "$SECRETS_DIR/aws-creds.secret_key" 2>/dev/null)
export AWS_SESSION_TOKEN=$(cat "$SECRETS_DIR/aws-creds.session_token" 2>/dev/null)

# Verify if the environment variables are set
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
    echo "Error: One or more AWS environment variables could not be set. Exiting."
    exit 1
fi

# Final confirmation message
echo "AWS credentials have been successfully set from Vault"

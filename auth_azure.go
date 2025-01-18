package main

import (
	"encoding/json" // Added this import to fix the json.Unmarshal() usage
	"fmt"
	"io/ioutil"
	"net/http"
	"os"

	"github.com/hashicorp/vault/api"
)

// Azure authentication plugin
type authAzurePlugin struct {
	// the vault client
	client *api.Client
}

// NewAzurePlugin creates a new Azure authentication plugin
func NewAzurePlugin(client *api.Client) AuthInterface {
	return &authAzurePlugin{
		client: client,
	}
}

// Create retrieves the token from the Azure Instance Metadata Service or file
func (r authAzurePlugin) Create(cfg *vaultAuthOptions) (string, error) {
	// Extract role from environment variable or configuration file
	role := os.Getenv("VAULT_SIDEKICK_ROLE_ID")
	if cfg.FileName != "" {
		content, err := readConfigFile(cfg.FileName, cfg.FileFormat)
		if err != nil {
			return "", err
		}

		role = content.RoleID
	}

	// If role is not provided, use a default (or error out)
	if role == "" {
		return "", fmt.Errorf("role must be provided")
	}

	// Get Azure Managed Identity token from IMDS
	token, err := getAzureManagedIdentityToken()
	if err != nil {
		return "", err
	}

	// Prepare the payload for Vault Azure authentication
	payload := map[string]interface{}{
		"role": role,
		"jwt":  token,
	}

	// Handle the nonce if available
	nonceFile := os.Getenv("VAULT_SIDEKICK_NONCE_FILE")
	if nonceFile != "" {
		nonce, err := ioutil.ReadFile(nonceFile)
		if err != nil {
			return "", err
		}
		if string(nonce) != "" {
			payload["nonce"] = string(nonce)
		}
	}

	// Call Vault to authenticate using the Azure token
	resp, err := r.client.Logical().Write("auth/azure/login", payload)
	if err != nil {
		return "", err
	}

	// Return the Vault client token
	return resp.Auth.ClientToken, nil
}

// getAzureManagedIdentityToken retrieves the Managed Identity token from the Azure IMDS endpoint
func getAzureManagedIdentityToken() (string, error) {
	// Azure IMDS endpoint to get the Managed Identity token
	url := "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net"
	client := &http.Client{}

	// Create the request
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", err
	}

	// Add the header to request the metadata
	req.Header.Set("Metadata", "true")

	// Send the request to the IMDS service
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	// Extract the token from the response
	token, err := parseAzureTokenResponse(body)
	if err != nil {
		return "", err
	}

	return token, nil
}

// parseAzureTokenResponse parses the JSON response from the Azure IMDS service
func parseAzureTokenResponse(responseBody []byte) (string, error) {
	// Example response:
	// {"access_token":"<token>","expires_in":3600,"token_type":"Bearer"}
	// Parse the JSON and extract the access_token field

	var response map[string]interface{}
	err := json.Unmarshal(responseBody, &response)
	if err != nil {
		return "", err
	}

	// Get the access token from the response
	token, found := response["access_token"].(string)
	if !found {
		return "", fmt.Errorf("missing 'access_token' in the response")
	}

	return token, nil
}

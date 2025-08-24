#!/bin/bash
set -euo pipefail

# =========================
# Configuration
# =========================
CERT_FILE="local/server01/sealed-secrets-certificate.pem"

# =========================
# Helper Functions
# =========================

# Print error and exit
err() {
    echo "❌ Error: $*" >&2
    exit 1
}

# Prompt for hidden secret input
read_secret() {
    local prompt="$1" secret_value
    printf "%s" "$prompt" >&2
    IFS= read -r -s secret_value
    printf "\n" >&2
    printf "%s" "$secret_value"
}

# Prompt with default
prompt() {
    local message="$1"
    local default="${2:-}"
    local input
    read -rp "$message" input
    echo "${input:-$default}"
}

# =========================
# Main Script
# =========================

# Ensure dependencies
command -v kubectl >/dev/null 2>&1 || err "kubectl is not installed"
command -v kubeseal >/dev/null 2>&1 || err "kubeseal is not installed"
[[ -f "$CERT_FILE" ]] || err "Certificate file '$CERT_FILE' not found"

# Namespace
namespace=$(prompt "Enter the namespace to create the secret in: ")
[[ -n "$namespace" ]] || err "Namespace cannot be empty"

# Secret name
secret_name=$(prompt "Enter the name of the secret: ")
[[ -n "$secret_name" ]] || err "Secret name cannot be empty"

# Collect key-value pairs
declare -a secret_keys secret_values
while true; do
    key=$(prompt "Enter a secret key: ")
    [[ -n "$key" ]] || { echo "⚠️ Key cannot be empty. Try again."; continue; }

    value=$(read_secret "Enter the secret value: ")
    secret_keys+=("$key")
    secret_values+=("$value")

    cont=$(prompt "Do you want to add another secret key (y/n)? " "n")
    [[ "$cont" =~ ^[Yy]$ ]] || break
done

# Validate at least one secret
(( ${#secret_keys[@]} > 0 )) || err "No secret keys were provided"

# Create temporary directory
temp_dir=$(mktemp -d)
cleanup() {
    rm -rf "$temp_dir"
}
trap cleanup EXIT
temp_secret_file="$temp_dir/secret.yaml"
temp_sealed_file="$temp_dir/sealed-secret.yaml"

# Build kubectl command
kubectl_cmd=(kubectl create secret generic "$secret_name" --namespace="$namespace" --dry-run=client -o yaml)
for i in "${!secret_keys[@]}"; do
    kubectl_cmd+=("--from-literal=${secret_keys[$i]}=${secret_values[$i]}")
done

# Generate secret YAML
"${kubectl_cmd[@]}" > "$temp_secret_file" || err "Failed to create secret YAML"

# Seal the secret
kubeseal --cert "$CERT_FILE" --format yaml < "$temp_secret_file" > "$temp_sealed_file" \
    || err "Failed to create sealed secret. Verify the certificate file."

# Output result
echo "✅ Sealed Secret created successfully!"
echo "===================================="
cat "$temp_sealed_file"
echo "===================================="

# Cleanup sensitive vars
unset -v secret_values
unset -v secret_keys

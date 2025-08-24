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

# =========================
# Main Script
# =========================

# Ensure dependencies
command -v kubectl >/dev/null 2>&1 || err "kubectl is not installed"
command -v kubeseal >/dev/null 2>&1 || err "kubeseal is not installed"
[[ -f "$CERT_FILE" ]] || err "Certificate file '$CERT_FILE' not found"

# Create temporary directory
temp_dir=$(mktemp -d)
cleanup() {
    rm -rf "$temp_dir"
}
trap cleanup EXIT
temp_secret_file="$temp_dir/secret.yaml"
temp_sealed_file="$temp_dir/sealed-secret.yaml"

# Predefined secret
cat > "$temp_secret_file" <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: foobar-secret
  namespace: foobar-namespace
data:
  foo: YmFy
EOF

$EDITOR "$temp_secret_file"

# Seal the secret
kubeseal --cert "$CERT_FILE" --format yaml < "$temp_secret_file" > "$temp_sealed_file" \
    || err "Failed to create sealed secret. Verify the certificate file."

# Output result
echo "✅ Sealed Secret created successfully!"
echo "===================================="
cat "$temp_sealed_file"
echo "===================================="

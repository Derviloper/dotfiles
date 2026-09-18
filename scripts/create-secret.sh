#!/usr/bin/env bash
# Seal a Kubernetes Secret so it can be committed. Opens an editor on a skeleton
# Secret, then encrypts it to the target cluster's sealed-secrets certificate.
set -euo pipefail

# Must match the host `just fetch-cert` was run for: a SealedSecret encrypted to
# the wrong controller is accepted by the API server and then never decrypts.
host="${1:-server01}"
cert_file="local/$host/sealed-secrets-certificate.pem"

err() {
  echo "❌ Error: $*" >&2
  exit 1
}

command -v kubectl >/dev/null 2>&1 || err "kubectl is not installed"
command -v kubeseal >/dev/null 2>&1 || err "kubeseal is not installed"
[[ -f $cert_file ]] || err "Certificate '$cert_file' not found. Fetch it with: just fetch-cert $host"

# EDITOR is routinely unset in a non-login shell, where under `set -u` a bare
# $EDITOR would abort *after* the skeleton is written. Split on whitespace: on
# desktop01 this is `code --wait` (modules/home/vscode.nix), and an editor that
# returns before the file is saved would seal the untouched skeleton.
read -r -a editor_cmd <<<"${EDITOR:-${VISUAL:-vi}}"

temp_dir=$(mktemp -d)
cleanup() {
  rm -rf "$temp_dir"
}
trap cleanup EXIT
temp_secret_file="$temp_dir/secret.yaml"
temp_sealed_file="$temp_dir/sealed-secret.yaml"

cat >"$temp_secret_file" <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: foobar-secret
  namespace: foobar-namespace
data:
  foo: YmFy
EOF

# An unedited template seals cleanly into a valid SealedSecret holding nothing
# but the placeholder.
before=$(sha256sum <"$temp_secret_file")
"${editor_cmd[@]}" "$temp_secret_file"
if [[ $(sha256sum <"$temp_secret_file") == "$before" ]]; then
  err "Secret unchanged -- nothing sealed."
fi

kubeseal --cert "$cert_file" --format yaml <"$temp_secret_file" >"$temp_sealed_file" ||
  err "Failed to create sealed secret. Verify the certificate file."

echo "✅ Sealed Secret created successfully against $host!"
echo "===================================="
cat "$temp_sealed_file"
echo "===================================="

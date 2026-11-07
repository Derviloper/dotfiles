#!/usr/bin/env bash
# Pull a host's k3s kubeconfig into ~/.kube/config.
set -euo pipefail

server="${1:-server01}"
kubeconfig="$HOME/.kube/config"

mkdir -p "$HOME/.kube"

# A cluster-admin credential, and the only copy of whatever other contexts are
# already in it -- overwriting silently loses every other cluster configured.
if [ -e "$kubeconfig" ]; then
  backup="$kubeconfig.$(date +%Y%m%d%H%M%S).bak"
  echo "$kubeconfig already exists." >&2
  printf 'Overwrite it? The current one is kept at %s (y/N): ' "$backup"
  read -r reply
  [[ $reply =~ ^[Yy]$ ]] || {
    echo "aborted" >&2
    exit 1
  }
  cp -p "$kubeconfig" "$backup"
  chmod 600 "$backup"
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

rsync -azP --rsync-path="sudo rsync" "$server:/etc/rancher/k3s/k3s.yaml" "$tmp"

# k3s writes 127.0.0.1:6443, which is left alone: the firewall does not expose
# the API server, so it is reached through `just tunnel`, which listens there.
install -m 600 "$tmp" "$kubeconfig"
echo "Wrote $kubeconfig for $server. Run 'just tunnel $server' before kubectl."

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

# k3s writes the loopback address, correct only on the node itself. Substitute
# whatever ssh resolves to, including ~/.ssh/config.local where server01's real
# address lives.
hostname=$(ssh -G "$server" | awk '/^hostname / { print $2 }')
[ -n "$hostname" ] || {
  echo "could not resolve a hostname for '$server' from ssh config" >&2
  exit 1
}
sed -i "s/127.0.0.1/$hostname/g" "$tmp"

# Move into place only after the rewrite, so an interrupted transfer cannot
# leave a kubeconfig pointing at 127.0.0.1.
install -m 600 "$tmp" "$kubeconfig"
echo "Wrote $kubeconfig for $server ($hostname)."

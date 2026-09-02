#!/usr/bin/env bash
# Install a host from scratch with nixos-anywhere. ERASES THE TARGET DISK.
set -euo pipefail

server="${1:-server01}"

printf 'Connect as root? (y/N): '
read -r use_root
if [[ $use_root =~ ^[Yy]$ ]]; then
  target_host="root@$server"
else
  target_host="$server"
fi

extra_files=$(mktemp -d)
cleanup() { rm -rf "$extra_files"; }
trap cleanup EXIT

install -d -m755 "$extra_files/etc/ssh"

# The host SSH key is the root of trust for sops-nix: sops-nix converts it to an
# age identity at activation, so it must be in place before the first boot.
nix-shell -p sops --run "
  sops decrypt hosts/$server/secrets/ssh_host_ed25519_key > $extra_files/etc/ssh/ssh_host_ed25519_key &&
  sops decrypt hosts/$server/secrets/ssh_host_ed25519_key.pub > $extra_files/etc/ssh/ssh_host_ed25519_key.pub
"
chmod 600 "$extra_files/etc/ssh/ssh_host_ed25519_key"
chmod 644 "$extra_files/etc/ssh/ssh_host_ed25519_key.pub"

nix run github:nix-community/nixos-anywhere -- \
  --generate-hardware-config nixos-generate-config \
  "./hosts/$server/hardware.nix" \
  --extra-files "$extra_files" \
  --flake ".#$server" \
  --target-host "$target_host"

hostname=$(ssh -G "$server" | awk '/^hostname / { print $2 }')

until nc -z "$hostname" 22 2>/dev/null; do
  sleep 1
done

ssh-keygen -R "$hostname"
ssh-keyscan -H "$hostname" >>~/.ssh/known_hosts

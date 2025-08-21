#!/bin/bash
set -euo pipefail

printf "Enter the server you want to install [server01]: "
read -r server
server="${server:-server01}"

printf "Do you want to connect as root? (y/N): "
read -r use_root
if [[ "$use_root" =~ ^[Yy]$ ]]; then
  target_host="root@$server"
else
  target_host="$server"
fi

extra_files=$(mktemp -d)
cleanup() {
  rm -rf "$extra_files"
}
trap cleanup EXIT

install -d -m755 "$extra_files/etc/ssh"

nix-shell -p sops --run "
  sops decrypt hosts/$server/secrets/ssh_host_ed25519_key > $extra_files/etc/ssh/ssh_host_ed25519_key &&
  sops decrypt hosts/$server/secrets/ssh_host_ed25519_key.pub > $extra_files/etc/ssh/ssh_host_ed25519_key.pub
"
chmod 600 "$extra_files/etc/ssh/ssh_host_ed25519_key"
chmod 644 "$extra_files/etc/ssh/ssh_host_ed25519_key.pub"

nix run github:nix-community/nixos-anywhere -- \
  --generate-hardware-config nixos-generate-config \
  ./hosts/"$server"/hardware-configuration.nix \
  --extra-files "$extra_files" \
  --flake .#"$server" \
  --target-host "$target_host"

hostname=$(ssh -G "$server" | awk '/^hostname / { print $2 }')

until nc -z "$hostname" 22 2>/dev/null; do
  sleep 1
done

ssh-keygen -R "$hostname"
ssh-keyscan -H "$hostname" >> ~/.ssh/known_hosts

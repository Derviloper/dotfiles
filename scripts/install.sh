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

# Refuse to run if the disk disko would format is not the disk the target has.
# This is the one mistake here that cannot be undone, and VPS images routinely
# present /dev/vda where a bare-metal install had /dev/sda. Read the configured
# device from the evaluated config rather than grepping disko.nix, so this can
# never disagree with what disko will actually do.
want=$(nix eval --raw ".#nixosConfigurations.$server.config.disko.devices.disk.main.device")
have=$(ssh "$target_host" 'lsblk -dno PATH,SIZE,TYPE' | awk '$3 == "disk"')

if ! grep -qE "^${want}[[:space:]]" <<<"$have"; then
  echo "ERROR: $server's disko.nix formats '$want', which the target does not have." >&2
  echo "Disks on $target_host:" >&2
  awk '{ print "  " $0 }' <<<"$have" >&2
  echo "Fix hosts/$server/disko.nix before installing." >&2
  exit 1
fi
echo "Disk check: $want present on $target_host."

extra_files=$(mktemp -d)
cleanup() { rm -rf "$extra_files"; }
trap cleanup EXIT

# Not every host has secrets. homelab, for instance, only gained them for the
# Tailscale auth key -- a host with none is still perfectly installable.
if [ -d "hosts/$server/secrets" ]; then
  install -d -m755 "$extra_files/etc/ssh"

  # The host SSH key is the root of trust for sops-nix: sops-nix converts it to
  # an age identity at activation, so it must be in place before the first boot.
  nix-shell -p sops --run "
    sops decrypt hosts/$server/secrets/ssh_host_ed25519_key > $extra_files/etc/ssh/ssh_host_ed25519_key
  "
  chmod 600 "$extra_files/etc/ssh/ssh_host_ed25519_key"

  # Only the private half is encrypted. The public key is committed in plaintext
  # -- it is a public key, and encrypting it just cost this script a decrypt.
  install -m 644 "hosts/$server/secrets/ssh_host_ed25519_key.pub" \
    "$extra_files/etc/ssh/ssh_host_ed25519_key.pub"
  extra_files_args=(--extra-files "$extra_files")
else
  echo "No hosts/$server/secrets -- installing without a pre-seeded host key."
  # Passing an empty --extra-files directory is not the same as omitting it.
  extra_files_args=()
fi

nix run github:nix-community/nixos-anywhere -- \
  --generate-hardware-config nixos-generate-config \
  "./hosts/$server/hardware.nix" \
  "${extra_files_args[@]}" \
  --flake ".#$server" \
  --target-host "$target_host"

hostname=$(ssh -G "$server" | awk '/^hostname / { print $2 }')

until nc -z "$hostname" 22 2>/dev/null; do
  sleep 1
done

ssh-keygen -R "$hostname"
ssh-keyscan -H "$hostname" >>~/.ssh/known_hosts

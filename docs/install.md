# Installing a host from scratch

> The disko steps **erase the target disk**. Make sure you have the right
> machine and the right device name (`lsblk`); the layouts are in
> `hosts/<host>/disko.nix`.

## Remote install (preferred)

Works when the target is reachable over SSH as root -- booted into the NixOS
installer with a root password set (`passwd`), or any existing Linux.

```sh
nix develop
just install server01
```

`scripts/install.sh` decrypts the host's SSH host key, hands it to
`nixos-anywhere` via `--extra-files`, regenerates `hardware.nix` from the real
hardware, kexecs into an installer, runs disko, installs, and reboots.

The host key placement matters: sops-nix derives its age identity from
`/etc/ssh/ssh_host_ed25519_key`, so without it the first activation cannot
decrypt anything.

For a host with no secrets (`homelab`), the flake alone is enough:

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake .#homelab --target-host homelab
```

## Physical install

Boot the NixOS installer on the target, then:

```sh
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko -- \
  --mode destroy,format,mount \
  --flake github:Derviloper/dotfiles#<host>

sudo nixos-install --flake github:Derviloper/dotfiles#<host>
sudo reboot
```

**Different hardware?** `hosts/<host>/hardware.nix` is committed and specific to
the original machine. Regenerate before installing:

```sh
nixos-generate-config --no-filesystems --root /mnt
```

## After first boot

- Log in as the host's user with your SSH key. Root SSH is disabled and
  `PasswordAuthentication` is off on every host.
- `desktop01` only: clone this repo to `~/Projects/dotfiles` if you want the
  live-edit workflow (`local.liveConfig`). Nothing breaks without it -- the
  window-manager configs fall back to the store.

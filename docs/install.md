# Installing from scratch

Rebuilding the whole fleet takes four commands and one secret: your personal SSH
key. That key is your SSH auth to both servers, your git signing key, **and** the
sops admin identity -- `ssh-to-age ~/.ssh/id_ed25519` yields the `&admin`
recipient in [.sops.yaml](../.sops.yaml). So it decrypts each server's host key,
sops-nix turns that into an age identity at activation, and on server01 that
unwraps the sealed-secrets controller key -- which is why Argo CD can
reconstitute every committed SealedSecret on a cluster built from nothing.

Paste the same *public* key into your VPS provider's console when creating the
machine and it also gets you `root@` for nixos-anywhere. One key, three roles.

> The install steps **erase the target disk**. Both entry points refuse to run if
> the disk `disko.nix` names is not present on the target, but check `lsblk`
> yourself if you are installing somewhere new -- VPS images usually present
> `/dev/vda` where bare metal had `/dev/sda`.

## 1. desktop01, from the NixOS live ISO

```sh
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:Derviloper/dotfiles#install -- desktop01
reboot
```

The experimental-features flag is unavoidable: the stock ISO enables neither, and
this is the first thing you run.

The installer checks the disk, asks you to type the hostname to confirm, then
runs disko and `nixos-install` against the exact revision you invoked.

## 2. The one manual input

```sh
just bootstrap ~/path/to/id_ed25519
```

Installs the key, derives its public half, writes
`~/.config/sops/age/keys.txt`, verifies it can actually decrypt this repo's
secrets, and prompts you to set a login password. It refuses to overwrite an
existing key that differs.

The repo checkout is already there: `seed-dotfiles.service` clones it before the
display manager starts. That matters more than it sounds -- desktop01 symlinks
its bspwm, sxhkd and eww configs into that checkout, and `bspwmrc` is what
launches sxhkd and eww, so without it you would get a blank screen with no way to
open a terminal.

**If you do get a blank screen**, the clone failed (no network at first boot is
the usual cause). Switch to a console with Ctrl+Alt+F2, log in -- the password is
empty until you run `just bootstrap` -- and clone by hand:

```sh
git clone https://github.com/Derviloper/dotfiles ~/Projects/dotfiles
sudo systemctl restart display-manager
```

## 3. The servers, from desktop01

```sh
just install server01
just install homelab
```

`scripts/install.sh` decrypts the host's SSH host key, hands it to
nixos-anywhere via `--extra-files`, regenerates `hardware.nix` from the real
hardware, then partitions, installs and reboots. Hosts without a `secrets/`
directory install fine without that step.

Placing the host key before first boot is what makes sops work at all: sops-nix
derives its age identity from `/etc/ssh/ssh_host_ed25519_key`, so without it the
first activation cannot decrypt anything.

Then everything else comes up on its own:

- **server01** -- k3s starts, sops hands it the sealed-secrets controller key,
  the app-of-apps syncs, and Argo CD brings up all twelve applications.
- **homelab** -- `haos-provision` downloads the current Home Assistant OS image,
  defines the VM and autostarts it; the USB dongles attach on their own. Restore
  your Home Assistant backup from its own UI. See
  [homelab-haos.md](homelab-haos.md).

Both join the tailnet unattended, provided the Tailscale OAuth secret is set --
see [secrets.md](secrets.md).

## Physical install, without the app

```sh
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko -- \
  --mode destroy,format,mount \
  --flake github:Derviloper/dotfiles#<host>

sudo nixos-install --flake github:Derviloper/dotfiles#<host>
```

**Different hardware?** `hosts/<host>/hardware.nix` is committed and specific to
the original machine. `just install` regenerates it automatically; for a manual
install run `nixos-generate-config --no-filesystems --root /mnt` and replace it.

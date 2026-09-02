# dotfiles

NixOS configuration for three machines, managed as a single flake. Disks are
declared with [disko](https://github.com/nix-community/disko), user environments
with [home-manager](https://github.com/nix-community/home-manager), secrets with
[sops-nix](https://github.com/Mic92/sops-nix), and remote updates run through
[deploy-rs](https://github.com/serokell/deploy-rs).

## Hosts

| Host | Role | Notes |
| --- | --- | --- |
| `desktop01` | Graphical dev workstation | VMware guest, bspwm + sxhkd + eww, rebuilt in place |
| `homelab` | Headless KVM host | `br0` bridge, Tailscale, runs the Home Assistant OS VM |
| `server01` | Single-node k3s cluster | Argo CD GitOps, Traefik, monitoring stack |

All three run NixOS 26.05 on `x86_64-linux`.

## Layout

```
flake.nix              inputs, the host table, checks, devShell
lib/mkHost.nix         the one host constructor
profiles/              base -> {server, desktop, vmware-guest}; hosts compose these
modules/nixos/         system modules, imported by profiles
modules/home/          home-manager modules
hosts/<host>/          default.nix, hardware.nix, disko.nix, home.nix
kubernetes/cluster01/  Argo CD app-of-apps
scripts/  docs/
```

Modules are plain files with no aggregating `default.nix`. A host imports one
profile and reaches past it for anything one-off. `profiles/base.nix` is the
single place "every host gets this" is expressed -- its absence is what let
locale, nix settings, and the SSH hardening drift into three near-identical
copies across the three repos this replaces.

## Everyday use

Everything runs through [`just`](https://github.com/casey/just); `just` on its
own lists the recipes.

```sh
just check                  # formatting, lints, deploy checks, all toplevels
just diff homelab           # what would actually change (nvd)
just switch                 # rebuild this machine
just deploy homelab         # dry-activate, then activate remotely
just update                 # refresh flake inputs
```

`nix develop` drops you into a shell with sops, age, ssh-to-age, deploy-rs,
kubectl, helm, kubeseal, nvd and nh.

### Rebuilding vs. deploying

`desktop01` is rebuilt in place. Use `just boot` rather than `just switch` for
anything touching X11, the display manager, or PipeWire -- those half-apply on a
live switch and can leave you at a black screen.

`homelab` and `server01` are deployed with deploy-rs, which activates with
automatic rollback. `just deploy <host>` dry-activates first.

## Installing a host from scratch

See [docs/install.md](docs/install.md). Short version:

```sh
just install server01       # nixos-anywhere; ERASES THE TARGET DISK
```

## Secrets

Encrypted with sops-nix, keyed to each host's own SSH host key plus an admin key
that can decrypt everything. See [docs/secrets.md](docs/secrets.md) for the
recipient model, how to add a secret, and what has to be provisioned out of band.

## Design notes

A few choices that look wrong at a glance and are not:

- **`security.sudo.wheelNeedsPassword = false`** on all three hosts. deploy-rs
  activates over sudo, so this is what makes remote deployment work at all. Both
  servers are key-only with `PasswordAuthentication = false` and fail2ban.
- **`nix.settings.trusted-users` includes `@wheel`.** deploy-rs pushes
  locally-built store paths, which are rejected without it. This is effectively
  root-equivalent -- a deliberate tradeoff for a single-operator fleet.
- **`services.k3s.package` is pinned.** nixpkgs 25.11 defaulted to k3s 1.34 and
  26.05 defaults to 1.35, so without the pin an OS upgrade would silently
  upgrade the Kubernetes control plane. Bump it as its own change.
- **The two `disko.nix` files for `desktop01` and `homelab` are near-identical
  and stay that way.** A disko file is read once, under stress, immediately
  before it destroys a disk. Factoring it into a shared function is how you
  reformat the wrong machine.
- **`hosts/*/hardware.nix` is generator output** and excluded from the
  formatter, so `nixos-generate-config` output drops in unmodified.

## Related docs

- [docs/install.md](docs/install.md) -- installing a host from scratch
- [docs/secrets.md](docs/secrets.md) -- sops, age recipients, rotation
- [docs/homelab-haos.md](docs/homelab-haos.md) -- the Home Assistant OS VM
- [docs/kubernetes.md](docs/kubernetes.md) -- the k3s cluster and Argo CD

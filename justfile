_default:
    @just --list --unsorted

# Evaluate everything: formatting, lints, deploy checks, all three toplevels.
check:
    nix flake check --print-build-logs

# Format every tracked file (nix, yaml, sh, md).
fmt:
    nix fmt

# Build a host's toplevel without activating it.
build host:
    nix build ".#nixosConfigurations.{{ host }}.config.system.build.toplevel"

# Show what a rebuild would actually change on this machine.
diff host: (build host)
    nvd diff /run/current-system ./result

# Rebuild the local machine. Use `boot` for X11/display-manager changes.
switch:
    sudo nixos-rebuild switch --flake ".#$(hostname)"

boot:
    sudo nixos-rebuild boot --flake ".#$(hostname)"

# Dry-run a remote activation. Always run this before `deploy`.
dry-deploy host:
    nix run github:serokell/deploy-rs -- ".#{{ host }}" --dry-activate

deploy host: (dry-deploy host)
    nix run github:serokell/deploy-rs -- ".#{{ host }}"

# Install a host from scratch over SSH (erases its disk).
install host="server01":
    ./scripts/install.sh {{ host }}

# Pull a host's kubeconfig into ~/.kube/config.
kubeconfig host="server01":
    ./scripts/get-kubeconfig.sh {{ host }}

# Seal a Kubernetes Secret for committing.
seal:
    ./scripts/create-secret.sh

# Refresh flake inputs. CI builds the result on the PR.
update:
    nix flake update

# --- live-config reload targets -------------------------------------------
# These only do anything on the machine with local.liveConfig.enable = true,
# where ~/.config/{bspwm,eww,sxhkd} symlink back into this checkout. Editing a
# different checkout silently has no effect, so refuse to run from one.

_assert-live:
    #!/usr/bin/env bash
    set -euo pipefail
    live="${DOTFILES_DIR:-}"
    if [ -z "$live" ]; then
      echo "DOTFILES_DIR unset: this host does not have local.liveConfig.enable." >&2
      exit 1
    fi
    if [ "$(realpath "$PWD")" != "$(realpath "$live")" ]; then
      echo "Wrong checkout: live configs point at $live, you are in $PWD." >&2
      exit 1
    fi

watch-bspwm: _assert-live
    watchexec -w modules/home/bspwm -- bspc wm -r

watch-eww: _assert-live
    watchexec -w modules/home/eww -- eww reload

watch-sxhkd: _assert-live
    watchexec -w modules/home/sxhkd -- pkill -USR1 -x sxhkd

_default:
    @just --list --unsorted

# One-time setup on a freshly installed desktop01: install the one SSH key.
bootstrap keyfile:
    #!/usr/bin/env bash
    set -euo pipefail

    # That key is the only secret you ever type. It is your SSH auth to both
    # servers, your git signing key, and the sops admin identity that decrypts
    # everything else -- which is why one key is enough for the whole fleet.

    key="$HOME/.ssh/id_ed25519"

    if [ -e "$key" ] && ! cmp -s "{{ keyfile }}" "$key"; then
      echo "$key already exists and differs from {{ keyfile }}." >&2
      echo "Move it aside first -- refusing to overwrite a private key." >&2
      exit 1
    fi

    install -d -m 700 "$HOME/.ssh"
    install -m 600 "{{ keyfile }}" "$key"
    ssh-keygen -y -f "$key" > "$key.pub"
    chmod 644 "$key.pub"

    # sops-nix derives each host's identity from its SSH host key; yours is
    # derived the same way, which is why one key covers the whole fleet.
    install -d -m 700 "$HOME/.config/sops/age"
    ssh-to-age -private-key -i "$key" > "$HOME/.config/sops/age/keys.txt"
    chmod 600 "$HOME/.config/sops/age/keys.txt"

    # Fail here rather than three commands later inside an install, where a
    # wrong key surfaces as an unexplainable decryption error.
    if ! sops decrypt hosts/server01/secrets/sops.yaml > /dev/null 2>&1; then
      echo "That key cannot decrypt this repo's secrets -- wrong key?" >&2
      echo "It yields recipient: $(ssh-to-age < "$key.pub")" >&2
      grep -E '&admin ' .sops.yaml >&2
      exit 1
    fi

    echo "Key installed and verified against server01's secrets."
    echo "Set a login password (the installer leaves it empty):"
    passwd

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

# Fetch the sealed-secrets public cert into local/ (gitignored). Needed by `seal`.
fetch-cert host="server01":
    mkdir -p local/{{ host }}
    kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets --fetch-cert > local/{{ host }}/sealed-secrets-certificate.pem

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

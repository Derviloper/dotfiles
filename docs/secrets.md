# Secrets

Secrets are encrypted with [sops](https://github.com/getsops/sops) and decrypted
at activation by [sops-nix](https://github.com/Mic92/sops-nix).

## Recipient model

Every rule in [`.sops.yaml`](../.sops.yaml) has **two** recipients:

- the **host's own SSH host key**, converted to an age identity by sops-nix at
  activation. This is why `scripts/install.sh` places
  `/etc/ssh/ssh_host_ed25519_key` via `nixos-anywhere --extra-files` before the
  first boot -- it is the single bootstrap step, and it avoids needing a second
  secret to smuggle onto a new machine.
- an **admin key** (`~/.config/sops/age/keys.txt`) that can decrypt everything.

The admin key is not optional. The old `dev-dotfiles` repo encrypted its secret
to exactly one recipient -- `desktop01`'s host key -- which meant the secret
could only be edited from inside that VM, and would have become permanently
undecryptable if the VM were lost. Keep the admin key backed up offline.

Deriving a host's age recipient:

```sh
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
```

## Editing

```sh
nix develop                       # sops, age, ssh-to-age
sops hosts/server01/secrets/sops.yaml
```

After changing recipients in `.sops.yaml`, re-key existing files:

```sh
sops updatekeys hosts/server01/secrets/sops.yaml
```

## Adding a secret

1. `sops hosts/<host>/secrets/sops.yaml` and add the key.
1. Declare it under `sops.secrets.<name>` in the host's `default.nix` with
   `owner`, `mode`, `path` as needed.
1. Deploy.

## Provisioned out of band

Two things are deliberately **not** in this repo:

- **The personal SSH keypair** (`~/.ssh/id_ed25519`). The same public key is in
  `authorizedKeys` for `admin` on both servers, and both set
  `wheelNeedsPassword = false` -- so that one key is root on the whole fleet. It
  was previously committed sops-encrypted; it is now provisioned by hand, or via
  `nixos-anywhere --extra-files` alongside the host key. `modules/home/git.nix`
  expects it at `~/.ssh/id_ed25519.pub` for commit signing.
- **`local/server01/sealed-secrets-certificate.pem`**, the sealed-secrets public
  certificate used by `scripts/create-secret.sh`. `local/` is gitignored.

## Blast radius

`hosts/server01/secrets/sealed-secrets-key.yaml` is the sealed-secrets
**controller private key**, sops-encrypted. It ships here because it is what
makes the cluster reinstallable -- but it means one compromise of the admin age
key unseals every `SealedSecret` in `kubernetes/`. Two consequences:

- The admin age key belongs on a hardware token or an offline backup, not just
  on a laptop.
- This repository is public. The confidentiality of every cluster secret rests
  entirely on that age key.

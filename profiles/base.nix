# Imported by every host: locale, nix settings and the openssh block.
{ pkgs, username, ... }:
{
  imports = [
    ../modules/nixos/locale.nix
    ../modules/nixos/nix.nix
    ../modules/nixos/openssh.nix
    ../modules/nixos/zsh
  ];

  # One key for the whole fleet: `just bootstrap` installs it, and it is SSH auth
  # to every host, the git signing key and the sops admin identity (docs/install.md).
  # `username` comes from flake.nix's host table via mkHost's specialArgs, so this
  # lands on whichever account that host calls primary.
  users.users.${username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGzW3FD/tVwU7NsMUT0tEclsw+MC17lMGq2u7XjEPhbd"
  ];

  environment.systemPackages = with pkgs; [
    btop
    curl
    dig
    git
    vim
  ];

  # deploy-rs activates over sudo; the README explains the tradeoff.
  security.sudo.wheelNeedsPassword = false;
}

# Imported by every host. This is the layer whose absence let locale, nix
# settings and the openssh block drift into three near-identical copies.
{ pkgs, username, ... }:
{
  imports = [
    ../modules/nixos/locale.nix
    ../modules/nixos/nix.nix
    ../modules/nixos/openssh.nix
    ../modules/nixos/zsh
  ];

  # There is exactly one of these for the whole fleet -- it is the key
  # `just bootstrap` installs, and it is simultaneously SSH auth to every host,
  # the git signing key, and the sops admin identity (see docs/install.md).
  # Declared here rather than in each host's default.nix, where it was three
  # verbatim copies of one string.
  #
  # `username` comes from the host table in flake.nix via mkHost's specialArgs,
  # so this lands on whichever account that host calls its primary one.
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

  # deploy-rs activates over sudo. See the README for why this is a deliberate
  # choice rather than an oversight.
  security.sudo.wheelNeedsPassword = false;
}

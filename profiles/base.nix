# Imported by every host. This is the layer whose absence let locale, nix
# settings and the openssh block drift into three near-identical copies.
{ pkgs, ... }:
{
  imports = [
    ../modules/nixos/locale.nix
    ../modules/nixos/nix.nix
    ../modules/nixos/openssh.nix
    ../modules/nixos/zsh
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

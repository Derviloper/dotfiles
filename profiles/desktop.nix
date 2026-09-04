# Graphical workstation.
{ lib, pkgs, ... }:
{
  imports = [
    ./base.nix
    ../modules/nixos/desktop/file-manager.nix
    ../modules/nixos/desktop/fonts.nix
    ../modules/nixos/desktop/sound.nix
    ../modules/nixos/desktop/xserver.nix
    ../modules/nixos/nix-ld.nix
  ];

  # German regional formats with an English UI. Headless hosts have no use for
  # LC_TELEPHONE or LC_PAPER, so this stays out of modules/nixos/locale.nix.
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # home-manager installs direnv and its nix-direnv wiring, but its shell
  # integration hooks into home-manager's own zsh module -- and zsh is
  # configured at system level here so that root gets the same shell. So the
  # hook belongs here. mkAfter keeps it behind the p10k instant-prompt block,
  # which has to come first.
  programs.zsh.interactiveShellInit = lib.mkAfter ''
    eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
  '';
}

{ pkgs, ... }:
{
  imports = [
    ../../modules/home/eww
    ../../modules/home/bspwm
    ../../modules/home/sxhkd
    ../../modules/home/ghostty.nix
    ../../modules/home/git.nix
    ../../modules/home/live-config.nix
    ../../modules/home/ssh.nix
    ../../modules/home/vscode.nix
  ];

  # This is the machine the repo is developed on, so window-manager configs are
  # symlinked into the checkout rather than read from the store.
  local.liveConfig.enable = true;

  # Dev tooling belongs to the user, not to environment.systemPackages.
  home.packages = with pkgs; [
    brave
    gcc
    gnumake
    libsecret
    nixfmt
    rustup
    vscode
    watchexec
  ];

  home.stateVersion = "25.11";
}

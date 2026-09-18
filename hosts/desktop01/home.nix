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

  # The machine this repo is developed on, so window-manager configs symlink into
  # the checkout rather than coming from the store.
  local.liveConfig.enable = true;

  # Per-project toolchains pinned by each project's flake (nvm covers projects
  # that only ship an .nvmrc). The shell hook lives in profiles/desktop.nix, since
  # zsh is configured at system level and enableZshIntegration has no hook here.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Compilers, debuggers and version managers are system-wide, in
  # modules/nixos/dev-tools.nix.
  home.packages = with pkgs; [
    brave
    libsecret
    nixfmt
    vscode
    watchexec
  ];

  home.stateVersion = "25.11";
}

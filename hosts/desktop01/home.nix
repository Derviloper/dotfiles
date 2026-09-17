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

  # Per-project toolchains pinned by each project's flake (nvm covers node
  # projects that only ship an .nvmrc). The shell hook lives in
  # profiles/desktop.nix: zsh is configured at system level here, so
  # home-manager.enableZshIntegration has nothing to hook into.
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

{ pkgs, ... }:
{
  environment = {
    systemPackages = with pkgs; [
      zsh-powerlevel10k
      pkgsBuildBuild.ghostty.terminfo
    ];

    etc."p10k.zsh".source = ./p10k.zsh;
  };

  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    interactiveShellInit = ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme

      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi

      source /etc/p10k.zsh
    '';
  };

  users.defaultUserShell = pkgs.zsh;

  home-manager.sharedModules = [ { home.file.".zshrc".text = ""; } ];
}

{ pkgs, ... }:
{
  # Configured at system level rather than in home-manager so that root gets the
  # same shell -- the reason this never lived in the home-manager tree.
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    interactiveShellInit = ''
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi
      source /etc/p10k.zsh
    '';
  };

  environment = {
    systemPackages = with pkgs; [
      fzf
      zsh-powerlevel10k
      ghostty.terminfo
    ];

    etc."p10k.zsh".source = ./p10k.zsh;
  };

  users.defaultUserShell = pkgs.zsh;

  # home-manager would otherwise generate its own .zshrc and shadow the system
  # one entirely.
  home-manager.sharedModules = [ { home.file.".zshrc".text = ""; } ];
}

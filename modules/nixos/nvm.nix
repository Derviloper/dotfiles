# nvm is shell functions rather than a binary, so nixpkgs does not package it.
# The scripts come from the store; ~/.nvm stays a real writable directory because
# that is where `nvm install` puts node -- prebuilt binaries that run via nix-ld.
{ lib, pkgs, ... }:
let
  nvm = pkgs.fetchFromGitHub {
    owner = "nvm-sh";
    repo = "nvm";
    tag = "v0.40.7";
    hash = "sha256-bClD8XKR9yWztQQ3BDHES7VK2dyPCL1yqULpPR/K+wM=";
  };
in
{
  imports = [ ./nix-ld.nix ];

  # Order 1400 puts this behind p10k's instant-prompt block, which must come
  # first, and ahead of direnv's mkAfter hook, so a project's .envrc still has the
  # last word on PATH.
  #
  # Both links are needed: `nvm exec` runs "$NVM_DIR/nvm-exec", which sources
  # nvm.sh from its own directory without resolving the link. -ef is a builtin, so
  # a shell that already has them does not fork.
  programs.zsh.interactiveShellInit = lib.mkOrder 1400 ''
    export NVM_DIR="$HOME/.nvm"
    for f in nvm.sh nvm-exec; do
      if [[ ! "$NVM_DIR/$f" -ef ${nvm}/$f ]]; then
        mkdir -p "$NVM_DIR" && ln -sfn ${nvm}/$f "$NVM_DIR/$f"
      fi
    done
    unset f
    source ${nvm}/nvm.sh
  '';
}

# nvm is a set of shell functions rather than a binary, so nixpkgs does not
# package it. The scripts come from the store; each user's ~/.nvm stays a real,
# writable directory, because that is where `nvm install` puts node versions.
# Those are prebuilt, unpatched binaries -- they run only because of nix-ld.
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

  # zsh is configured at system level (modules/nixos/zsh), so the hook goes
  # there. Order 1400 puts it behind the p10k instant-prompt block, which has to
  # come first, and ahead of direnv's mkAfter hook, so that a project's .envrc
  # still has the last word on PATH.
  #
  # nvm.sh keeps an NVM_DIR that is already set, but `nvm exec` and `nvm run`
  # call "$NVM_DIR/nvm-exec", which in turn sources nvm.sh from the directory
  # it was called by -- without resolving the link. Hence both links. -ef is a
  # builtin test, so a shell that already has them does not fork.
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

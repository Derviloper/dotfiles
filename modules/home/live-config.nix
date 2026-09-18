# A full rebuild per keybinding tweak is painful, so on the machine this repo is
# developed on the window-manager configs symlink into the checkout. Everywhere
# else they come from the store, so a rebuild straight from GitHub is
# self-contained and never leaves a dangling symlink.
{ config, lib, ... }:
let
  cfg = config.local.liveConfig;
in
{
  options.local.liveConfig = {
    enable = lib.mkEnableOption "editing configs in place from the flake checkout";

    dir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Projects/dotfiles";
      description = ''
        Path to the flake checkout that live configs symlink into. Only consulted
        when {option}`local.liveConfig.enable` is true.
      '';
    };
  };

  config = {
    # Consumers call it with a repo-relative path plus the store fallback.
    _module.args.liveSource =
      relPath: storePath:
      if cfg.enable then config.lib.file.mkOutOfStoreSymlink "${cfg.dir}/${relPath}" else storePath;

    # `just watch-*` needs to know where to point watchexec.
    home.sessionVariables = lib.mkIf cfg.enable { DOTFILES_DIR = cfg.dir; };
  };
}

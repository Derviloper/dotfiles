# Window-manager configs are iterated on constantly, and a full rebuild per
# keybinding tweak is painful. On the machine this repo is developed on, symlink
# them straight into the checkout; everywhere else read them from the store, so
# a fresh `nixos-rebuild --flake github:Derviloper/dotfiles#desktop01` is
# self-contained and never produces a dangling symlink.
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
    # Consumers take `liveSource` as a module argument and call it with the
    # path relative to the repo root plus the store fallback.
    _module.args.liveSource =
      relPath: storePath:
      if cfg.enable then config.lib.file.mkOutOfStoreSymlink "${cfg.dir}/${relPath}" else storePath;

    # `just watch-*` needs to know where to point watchexec.
    home.sessionVariables = lib.mkIf cfg.enable { DOTFILES_DIR = cfg.dir; };
  };
}

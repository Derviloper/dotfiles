# Graphical workstation.
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
}

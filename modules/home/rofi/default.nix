{ liveSource, pkgs, ... }:
{
  # Not programs.rofi: it generates config.rasi from Nix, so every theme tweak
  # would need a rebuild instead of just reopening rofi.
  home.packages = [ pkgs.rofi ];

  xdg.configFile."rofi/config.rasi".source = liveSource "modules/home/rofi/config.rasi" ./config.rasi;
}

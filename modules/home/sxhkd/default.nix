{ liveSource, pkgs, ... }:
{
  # bspwmrc launches `sxhkd &`, so the binary has to be on the session PATH.
  # Shipped by the module that owns the config rather than a shared package
  # list, so the two cannot drift apart again.
  home.packages = [ pkgs.sxhkd ];

  xdg.configFile."sxhkd/sxhkdrc".source = liveSource "modules/home/sxhkd/sxhkdrc" ./sxhkdrc;
}

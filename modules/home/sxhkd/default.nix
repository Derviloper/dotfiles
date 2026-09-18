{ liveSource, pkgs, ... }:
{
  # bspwmrc launches `sxhkd &`, so it must be on the session PATH. Shipped by the
  # module that owns the config so the two cannot drift apart.
  home.packages = [ pkgs.sxhkd ];

  xdg.configFile."sxhkd/sxhkdrc".source = liveSource "modules/home/sxhkd/sxhkdrc" ./sxhkdrc;
}

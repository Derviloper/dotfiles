{ liveSource, ... }:
{
  xdg.configFile."bspwm/bspwmrc".source = liveSource "modules/home/bspwm/bspwmrc" ./bspwmrc;
}

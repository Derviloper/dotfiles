{ liveSource, ... }:
{
  xdg.configFile."sxhkd/sxhkdrc".source = liveSource "modules/home/sxhkd/sxhkdrc" ./sxhkdrc;
}

{ liveSource, pkgs, ... }:
{
  home.packages = [ pkgs.eww ];

  xdg.configFile = {
    "eww/eww.yuck".source = liveSource "modules/home/eww/eww.yuck" ./eww.yuck;
    "eww/eww.scss".source = liveSource "modules/home/eww/eww.scss" ./eww.scss;
    "eww/workspaces.sh".source = liveSource "modules/home/eww/workspaces.sh" ./workspaces.sh;
  };
}

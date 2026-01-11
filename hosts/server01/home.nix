{ ... }:
{
  programs = {
    home-manager.enable = true;
  };

  home = {
    username = "admin";
    homeDirectory = "/home/admin";

    stateVersion = "25.11";
  };
}

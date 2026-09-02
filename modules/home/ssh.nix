{ config, ... }:
let
  identity = "${config.home.homeDirectory}/.ssh/id_ed25519";
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      homelab = {
        HostName = "homelab";
        User = "admin";
        IdentityFile = identity;
      };
      server01 = {
        HostName = "server01";
        User = "admin";
        IdentityFile = identity;
      };
    };
  };
}

{ config, ... }:
let
  identity = "${config.home.homeDirectory}/.ssh/id_ed25519";
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # ssh takes the FIRST value for each keyword, so config.local wins over the
    # blocks below. That is where an address that must not be published goes:
    # server01's origin IP would let anyone bypass Cloudflare. See docs/secrets.md.
    includes = [ "config.local" ];

    settings = {
      homelab = {
        HostName = "homelab";
        User = "admin";
        IdentityFile = identity;
      };
      server01 = {
        # Overridden by ~/.ssh/config.local, which supplies the real address.
        HostName = "server01";
        User = "admin";
        IdentityFile = identity;
      };
    };
  };
}

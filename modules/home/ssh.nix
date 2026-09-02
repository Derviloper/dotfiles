{ config, ... }:
let
  identity = "${config.home.homeDirectory}/.ssh/id_ed25519";
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # ssh takes the FIRST value it obtains for each keyword, so anything in
    # config.local wins over the blocks below. That is where a host's real
    # address goes when it must not be published -- server01 sits behind
    # Cloudflare, and committing its origin IP here would let anyone bypass
    # the proxy. See docs/secrets.md.
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

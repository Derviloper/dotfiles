{ config, ... }:
{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "both";

    # Joining the tailnet is otherwise a manual `tailscale up`, which is the one
    # thing standing between "reinstall from the flake" and "reinstall, then go
    # find the admin console". An OAuth client secret is used rather than a
    # plain auth key because auth keys expire after at most 90 days, which would
    # break a from-scratch rebuild whenever the committed one had lapsed.
    #
    # Requires a tag:homelab tagOwners entry in the tailnet ACL *before* the
    # first join, or `tailscale up` fails with a tag error.
    authKeyFile = config.sops.secrets."tailscale/oauthSecret".path;
    authKeyParameters.preauthorized = true;
    extraUpFlags = [ "--advertise-tags=tag:homelab" ];

    # A separate unit from the auth key path, so this applies either way.
    extraSetFlags = [ "--advertise-routes=192.168.178.0/24" ];
  };
}

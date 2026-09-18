{ config, ... }:
{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "both";

    # Otherwise joining the tailnet is a manual `tailscale up` -- the one thing
    # between "reinstall from the flake" and a trip to the admin console. An OAuth
    # client secret rather than an auth key, which expires within 90 days and would
    # break a from-scratch rebuild. Needs a tag:homelab tagOwners entry in the
    # tailnet ACL *before* the first join, or `tailscale up` fails with a tag error.
    authKeyFile = config.sops.secrets."tailscale/oauthSecret".path;
    authKeyParameters.preauthorized = true;
    extraUpFlags = [ "--advertise-tags=tag:homelab" ];

    # A separate unit from the auth key path, so this applies either way.
    extraSetFlags = [ "--advertise-routes=192.168.178.0/24" ];
  };
}

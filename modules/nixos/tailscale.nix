{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "both";

    extraSetFlags = [
      "--advertise-routes=192.168.178.0/24"
    ];
  };
}

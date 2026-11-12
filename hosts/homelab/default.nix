{ config, ... }:
{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../profiles/server.nix
    ../../modules/nixos/libvirt-haos.nix
    ../../modules/nixos/tailscale.nix
  ];

  sops = {
    defaultSopsFile = ./secrets/sops.yaml;
    secrets = {
      "haos/mac" = { };
      "tailscale/oauthSecret" = { };
    };
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Turn the physical NIC into a bridge port so VMs can attach directly to the
  # LAN. The host's IP moves from enp2s0 onto br0 (DHCP). enp1s0 is unused.
  networking = {
    useDHCP = false;
    bridges.br0.interfaces = [ "enp2s0" ];
    interfaces.br0.useDHCP = true;

    firewall.allowedTCPPorts = [ 22 ];
  };

  # Host metrics for Home Assistant's Glances integration. The API has no auth
  # and lists every process's command line, so it is opened on the LAN bridge
  # only -- the HAOS VM reaches it there -- not on tailscale0.
  services.glances.enable = true;
  networking.firewall.interfaces.br0.allowedTCPPorts = [ config.services.glances.port ];

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  # The authorized key comes from profiles/base.nix.
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "libvirtd"
    ];
  };

  system.stateVersion = "26.05";
}

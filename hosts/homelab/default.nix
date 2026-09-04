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

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "libvirtd"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGzW3FD/tVwU7NsMUT0tEclsw+MC17lMGq2u7XjEPhbd"
    ];
  };

  system.stateVersion = "26.05";
}

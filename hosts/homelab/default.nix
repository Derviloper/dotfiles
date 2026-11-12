{ config, ... }:
let
  # influxdb2's provisioning reads the password and HA token files as the service
  # user, not through LoadCredential, and re-applies both on every start -- hence
  # owner and restart. adminToken only seeds the first setup (docs/secrets.md).
  influxSecret = {
    owner = "influxdb2";
    restartUnits = [ "influxdb2.service" ];
  };
in
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
      "influxdb2/adminPassword" = influxSecret;
      "influxdb2/adminToken" = influxSecret;
      "influxdb2/homeassistantToken" = influxSecret;
    };
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # External 4 TB USB HDD for bulky state. Deliberately not in disko.nix, which
  # would wipe it on `just install`. nofail on every mount from it: a missing disk
  # must not drop this headless box -- and the HAOS VM with it -- into emergency
  # mode.
  fileSystems = {
    "/mnt/hdd" = {
      device = "/dev/disk/by-uuid/7d9d8d81-8ad9-4eaa-8744-553069aabed0";
      fsType = "ext4";
      options = [
        "nofail"
        "noatime"
      ];
    };

    # InfluxDB's state directory: a subdirectory bound into place rather than the
    # whole disk mounted there, so the rest of the disk stays usable.
    "/var/lib/influxdb2" = {
      device = "/mnt/hdd/influxdb2";
      fsType = "none";
      options = [
        "bind"
        "nofail"
      ];
      depends = [ "/mnt/hdd" ];
    };
  };

  # Turn the physical NIC into a bridge port so VMs can attach directly to the
  # LAN. The host's IP moves from enp2s0 onto br0 (DHCP). enp1s0 is unused.
  networking = {
    useDHCP = false;
    bridges.br0.interfaces = [ "enp2s0" ];
    interfaces.br0.useDHCP = true;

    firewall.allowedTCPPorts = [ 22 ];

    # Services the HAOS VM reaches over the bridge, so not opened on tailscale0:
    # Glances has no auth and lists every process's command line, and InfluxDB is
    # plain HTTP.
    firewall.interfaces.br0.allowedTCPPorts = [
      config.services.glances.port
      8086 # influxdb2's default http-bind-address
    ];
  };

  services = {
    # Host metrics for Home Assistant's Glances integration.
    glances.enable = true;

    # Long-term history for Home Assistant (docs/homelab-haos.md), stored on the
    # HDD above. The org, bucket and HA's write token are provisioned from sops,
    # so a reinstall needs no clicking through the UI and HA's token keeps working.
    influxdb2 = {
      enable = true;
      settings.reporting-disabled = true;
      provision = {
        enable = true;
        initialSetup = {
          organization = "homelab";
          bucket = "homeassistant";
          passwordFile = config.sops.secrets."influxdb2/adminPassword".path;
          tokenFile = config.sops.secrets."influxdb2/adminToken".path;
        };
        organizations.homelab.auths.homeassistant = {
          description = "Home Assistant";
          writeBuckets = [ "homeassistant" ];
          tokenFile = config.sops.secrets."influxdb2/homeassistantToken".path;
        };
      };
    };

    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };
  };

  # With the disk absent, influxd must fail rather than initialise a fresh, empty
  # database on the SSD underneath the mount point. StateDirectory= implies this
  # today; spelled out so it does not hinge on the module keeping it.
  systemd.services.influxdb2.unitConfig.RequiresMountsFor = [ "/var/lib/influxdb2" ];

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

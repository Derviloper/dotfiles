{ username, ... }:
{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../profiles/desktop.nix
    ../../profiles/vmware-guest.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    nftables.enable = true;
    firewall.allowedTCPPorts = [
      22
      80
      443
    ];
  };

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "pipewire"
    ];
    # FIXME: empty password. sshd's PermitEmptyPasswords=no keeps this off the
    # network, but combined with wheelNeedsPassword=false it is root for anyone
    # at the VM console. Replace with hashedPasswordFile once a sops secret
    # exists for it; carried over as-is so the upgrade does not lock you out.
    initialHashedPassword = "";
  };

  system.stateVersion = "25.11";
}

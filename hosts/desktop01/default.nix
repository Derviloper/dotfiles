{ username, ... }:
{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../profiles/desktop.nix
    ../../profiles/vmware-guest.nix
    ../../modules/nixos/seed-dotfiles.nix
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
    # Empty only until first login: `just bootstrap` runs passwd immediately
    # after install, and initialHashedPassword applies solely at user creation,
    # so the real password sticks. Keeping it empty is what lets the installer
    # run unattended and still leave you able to log in at the console --
    # which is also the escape hatch if seed-dotfiles ever fails to clone.
    initialHashedPassword = "";
  };

  system.stateVersion = "25.11";
}

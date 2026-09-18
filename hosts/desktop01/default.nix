{ username, ... }:
{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../profiles/desktop.nix
    ../../profiles/vmware-guest.nix
    ../../modules/nixos/dev-tools.nix
    ../../modules/nixos/seed-dotfiles.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    nftables.enable = true;
    # Only ssh. This is a workstation and nothing here serves HTTP -- 80 and 443
    # were open with nothing behind them. A dev server that needs reaching from
    # the host is better forwarded over `ssh -L` than opened to the LAN.
    firewall.allowedTCPPorts = [ 22 ];
  };

  # sshd runs here with port 22 open, but PasswordAuthentication is off, so
  # without a key nothing can log in -- not even for `ssh -L`. The key itself is
  # in profiles/base.nix; it is the same one the servers take.
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "pipewire"
      "dialout"
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

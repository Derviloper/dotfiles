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
      "dialout"
    ];
    # sshd already runs here with port 22 open, but PasswordAuthentication is
    # off, so without a key nothing can log in -- not even for `ssh -L`. Same key
    # as the servers: the one `just bootstrap` installs.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGzW3FD/tVwU7NsMUT0tEclsw+MC17lMGq2u7XjEPhbd"
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

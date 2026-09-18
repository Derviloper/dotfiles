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
    # Only ssh: nothing here serves HTTP, and a dev server worth reaching is
    # better forwarded over `ssh -L` than opened to the LAN.
    firewall.allowedTCPPorts = [ 22 ];
  };

  # PasswordAuthentication is off, so the key in profiles/base.nix -- the same one
  # the servers take -- is the only way in, `ssh -L` included.
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "pipewire"
      "dialout"
    ];
    # Empty until first login: `just bootstrap` runs passwd right after install,
    # and initialHashedPassword applies only at user creation, so the real one
    # sticks. This is what keeps the installer unattended while leaving a console
    # login -- the escape hatch if seed-dotfiles ever fails to clone.
    initialHashedPassword = "";
  };

  system.stateVersion = "25.11";
}

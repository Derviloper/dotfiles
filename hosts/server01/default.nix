{
  inputs,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disk-config.nix
    ./hardware-configuration.nix
    ../../modules/nixos/shell
    ../../modules/nixos/k8s
  ];

  sops = {
    defaultSopsFile = ./secrets/sops.yaml;
    secrets = {
      "foo" = { };
      "sealed-secrets-key.yaml" = {
        sopsFile = ./secrets/sealed-secrets-key.yaml;
        key = "";
      };
    };
  };

  boot = {
    loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
    };

    kernel.sysctl = {
      "fs.inotify.max_user_instances" = 524288;
      "fs.inotify.max_user_watches" = 524288;
    };
  };

  time.timeZone = "Etc/UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    vim
    htop
    curl
    git
  ];

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
      extraConfig = ''
        PermitEmptyPasswords no
        ClientAliveInterval 300
        ClientAliveCountMax 3
      '';
    };

    # fail2ban = {
    #   enable = true;
    #   jails = {
    #     sshd = {
    #       enabled = true;
    #       port = "ssh";
    #       filter = "sshd";
    #       maxretry = 3;
    #       bantime = "1h";
    #       findtime = "10m";
    #     };
    #   };
    #   ignoreIP = [
    #     "127.0.0.1/8"
    #     "::1"
    #   ];
    # };

    journald = {
      forwardToSyslog = false;
      rateLimitInterval = "30s";
      rateLimitBurst = 1000;
      extraConfig = ''
        [Journal]
        Storage=persistent
        Compress=yes
        SystemMaxUse=200M
        SystemKeepFree=50M
      '';
    };

    logrotate.enable = true;

    ntp.enable = true;

    printing.enable = false;
    avahi.enable = false;
  };

  networking = {
    hostName = "server01";

    firewall = {
      allowedTCPPorts = [
        22 # ssh
        80 # http
        443 # https
        6443 # Kubernetes API Server
        8080 # testing
      ];
      allowedUDPPorts = [ ];
      extraInputRules = ''
        ip saddr 10.42.0.0/16 accept
        ip saddr 10.43.0.0/16 accept
      '';
    };

    nftables.enable = true;
  };

  systemd.coredump.enable = false;

  security.sudo.wheelNeedsPassword = false;

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILBm+ebJElO2PL4BqWgb/wdM+QZPYshQRDTSwnBGYobz"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.admin = ./home.nix;
  };

  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
    };

    settings = {
      trusted-users = [
        "root"
        "@wheel"
      ];
      max-jobs = 4;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };

  system = {
    autoUpgrade = {
      enable = true;
      allowReboot = true;
      flake = inputs.self.outPath;
      flags = [
        "--update-input"
        "nixpkgs"
        "--no-write-lock-file"
      ];
    };

    stateVersion = "25.05";
  };
}

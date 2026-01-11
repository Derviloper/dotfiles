{
  inputs,
  modulesPath,
  pkgs,
  config,
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
      "fs.inotify.max_user_instances" = 512;
      "fs.inotify.max_user_watches" = 2048;
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
    k3s = {
      enable = true;
      role = "server";
      extraFlags = [
        "--disable traefik"
        "--kube-apiserver-arg=oidc-issuer-url=https://authentik.derviloper.de/application/o/kube-apiserver/"
        "--kube-apiserver-arg=oidc-client-id=kube-apiserver"
        "--kube-apiserver-arg=oidc-username-claim=email"
        "--kube-apiserver-arg=oidc-groups-claim=groups"
      ];
      autoDeployCharts = {
        argocd = {
          name = "argo-cd";
          repo = "https://argoproj.github.io/argo-helm";
          version = "8.3.0";
          hash = "sha256-pIfbHJ4vafOPttJ/4ZupkObWQHl77KeOhFszkc4jkaQ=";
          targetNamespace = "argocd";
          createNamespace = true;
          values.configs.secret.annotations."sealedsecrets.bitnami.com/managed" = "true";
        };
      };
      manifests = {
        sealed-secret-key.source = config.sops.secrets."sealed-secrets-key.yaml".path;
        applications.source = ../../kubernetes/cluster01/applications.yaml;
      };
    };

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

    fail2ban.enable = true;

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
        25565 # Minecraft
      ];
      allowedUDPPorts = [ ];
      allowPing = true;
      pingLimit = "2/second";
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

    stateVersion = "25.11";
  };
}

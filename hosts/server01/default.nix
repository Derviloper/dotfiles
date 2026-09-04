{
  config,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
    ./hardware.nix
    ../../profiles/server.nix
  ];

  time.timeZone = "Etc/UTC";

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

  services = {
    k3s = {
      enable = true;
      role = "server";

      disable = [ "traefik" ];

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

    ntp.enable = true;
  };

  networking = {
    firewall = {
      allowedTCPPorts = [
        22 # ssh
        80 # http
        443 # https
        6443 # Kubernetes API Server
        25565 # Minecraft
      ];
      # The asterisk pod runs with hostNetwork, so it binds here rather than
      # behind a Service and this chain is its entire exposure surface. Keep
      # both in step with kubernetes/cluster01/asterisk/values.yaml.
      allowedUDPPorts = [
        5160 # Asterisk SIP signalling
      ];
      allowedUDPPortRanges = [
        {
          from = 10000;
          to = 10099;
        } # Asterisk RTP media
      ];
      allowPing = true;
      pingLimit = "2/second";
      extraInputRules = ''
        ip saddr 10.42.0.0/16 accept
        ip saddr 10.43.0.0/16 accept
      '';
    };

    nftables.enable = true;
  };

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGzW3FD/tVwU7NsMUT0tEclsw+MC17lMGq2u7XjEPhbd"
    ];
  };

  nix.settings.max-jobs = 4;

  system.stateVersion = "25.11";
}

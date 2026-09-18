{
  config,
  modulesPath,
  pkgs,
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

  sops.secrets."sealed-secrets-key.yaml" = {
    sopsFile = ./secrets/sealed-secrets-key.yaml;
    key = "";
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

      # Pinned so that a nixpkgs bump cannot silently move the Kubernetes
      # control plane: 25.11 defaulted to 1.34 and 26.05 defaults to 1.35, and
      # an unpinned `services.k3s.package` would have carried the cluster across
      # that boundary inside an unrelated deploy. Currently identical to the
      # nixpkgs default, so this is a no-op until the next release. Bump it as
      # its own change, one minor at a time -- k3s does not support downgrades.
      package = pkgs.k3s_1_35;

      disable = [ "traefik" ];

      autoDeployCharts = {
        argocd = {
          name = "argo-cd";
          repo = "https://argoproj.github.io/argo-helm";
          # This is the *bootstrap* Argo CD, installed by NixOS before Argo CD
          # manages itself. Renovate only watches kubernetes/**/application.yaml,
          # so it will never bump this -- keep it in step with
          # kubernetes/cluster01/argocd/application.yaml by hand. Drift here is
          # invisible until server01 is reinstalled from scratch.
          #
          # After changing the version, refresh the hash with:
          #   nix build .#nixosConfigurations.server01.config.system.build.toplevel
          # and copy the `got:` value from the mismatch error.
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

  # The authorized key comes from profiles/base.nix, which applies it to this
  # host's primary user.
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  nix.settings.max-jobs = 4;

  system.stateVersion = "25.11";
}
